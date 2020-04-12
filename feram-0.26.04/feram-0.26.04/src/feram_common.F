! feram_common.F -*-f90-*-
! Time-stamp: <2016-02-26 12:41:38 takeshi>
! Author: Takeshi NISHIMATSU
!!
#if defined HAVE_CONFIG_H
#  include "config.h"
#endif
#include "define.h"
subroutine feram_common(fn)
  use Param_module
  use Coord_module
  use date_and_time_module
  use msg_module
  implicit none  !关闭隐式声明变量的方法，例如matlab，这样可以避免错误的出现 
  !定义变量
  type(Param_type),save :: p
  type(Coord_type),save :: c
  character(len=FILE_NAME_LEN), intent(in) :: fn
  character(len=FILE_NAME_LEN)             :: fn_log, basename
  integer                                  :: fn_len_trim, suffix
  integer                                  :: OMP_GET_MAX_THREADS
  character(len=70) :: message
  integer           :: count_array(0:2)
  real*8            :: time_array(1:2)
  integer           :: count_rate, count_max, i
  !开启fftw，多线程操作，暂不考虑
  include 'fftw3.f03'
  integer :: ireturn
  ireturn = fftw_init_threads()   ! It is safe to call this function many times. See fftw3/threads/api.c.
  call fftw_plan_with_nthreads(OMP_GET_MAX_THREADS())   ! Also safe. See "Usage of Multi-threaded FFTW" in doc.

  fn_len_trim = len_trim(fn) !字符串长度
  suffix = index(fn,'.feram',back=.true.) !获取.feram的位置
  if (suffix.gt.0) then
     if (suffix.eq.fn_len_trim-5) then
        ! 为param的filename赋值：去掉后缀
        p%filename = fn(1:fn_len_trim-6)
     else if (index(fn,'.feram_check',back=.true.).eq.fn_len_trim-11) then
        ! 如果是feram.check，同样是为了赋值，先不考虑其处理方式
        p%filename = basename(fn(1:fn_len_trim-12)) ! ../../src/zzz16.feram_check -> zzz16 for `make distcheck`
     end if
  else
     !如果传入的字符串没有后缀，则直接赋值
     p%filename = fn
  end if

  fn_log = trim(p%filename) // '.log' !清除空格，并在后面加上后缀.log
  open(unit=UNIT_LOG,file=fn_log,status='replace')
  call msg(UNIT_LOG, __FILE__, __LINE__, 'START', PACKAGE_STRING) !PACKAGE_STRING is: feram by Takeshi NISHIMATSU 0.26.04
  call hostnm(message) !获取主机名称等相关信息
  call msg(UNIT_LOG, __FILE__, __LINE__, 'HOSTNAME', message)

  call system_clock(count_array(0)) !获取系统时间
  call date_and_time2message(message)
  call msg(UNIT_LOG, __FILE__, __LINE__, 'DATE_AND_TIME', message)

  write(message,'(i5)') OMP_GET_MAX_THREADS() !计算机能支持的最大线程数量
  call msg(UNIT_LOG, __FILE__, __LINE__, 'N_THREADS', message)

  !FFTW3：暂不考虑
#if defined(HAVE_LIBFFTW3) && !defined(WITH_FFT_MKL)
  ireturn = fftw_import_wisdom_from_filename(C_CHAR_"wisdom"//C_NULL_CHAR)
  if (ireturn.eq.1) then
     call msg(UNIT_LOG, __FILE__, __LINE__, 'FFTW_WISDOM', 'Successfully imported FFTW wisdom in current directory.')
  else
     call msg(UNIT_LOG, __FILE__, __LINE__, 'FFTW_WISDOM', 'Failed to import FFTW wisdom in current directory.')
     ireturn = fftw_import_system_wisdom()
     if (ireturn.eq.1) then
        call msg(UNIT_LOG, __FILE__, __LINE__, 'FFTW_WISDOM', 'Successfully imported FFTW system wisdom, /etc/fftw/wisdom.')
     else
        call msg(UNIT_LOG, __FILE__, __LINE__, 'FFTW_WISDOM', 'Could not import FFTW system wisdom. All FFTW plans will be made by myself.')
     end if
  end if
#endif
  !读取参数：param_module.F文件中
  call  read_Param(p,fn)
  call  make_Param(p)
  call write_Param(p)
  if (p%continue) then
     if (.not.allocated(c%dipoR)) then
        write(0,'(a,a,i2,a)') __FILE__, ':', __LINE__, ': continue=.true. but cannot continue the calculation, because there is no previous result.'
        stop 1
     end if
  else
     call alloc_Coord(p,c)
  end if
  call dipole_dipole(p,c)
  call elastic(p,c)
  !Instead, read_defects_u(p,c) is called in initialize_dipoR()! call make_mass_matrix(p,c)

  call system_clock(count_array(1))
  call date_and_time2message(message)
  call msg(UNIT_LOG, __FILE__, __LINE__, 'DATE_AND_TIME', trim(message)//' Ready for simulation!!!')
  flush(UNIT_LOG)

  select case (p%method)
  case ('md','vs','lf')
     call molecular_dynamics(p,c)
  case ('hl')
     call hysteresis_loop(p,c)
  case default
     write(message,'(a,a,a)') &
          ": '", trim(p%method), "' is an illegal or not-yet-implemented method. Stop."
     call msg(UNIT_LOG, __FILE__, __LINE__, 'FATAL', message)
  end select

  call system_clock(count_array(2),count_rate,count_max)
  call date_and_time2message(message)
  call msg(UNIT_LOG, __FILE__, __LINE__, 'DATE_AND_TIME', message)

  do i = 1, 2
     time_array(i) = dble(count_array(i)-count_array(i-1))/count_rate
     if (time_array(i)<0.0d0) time_array(i)=time_array(i)+dble(count_max)/count_rate
  end do
  call msg_ez(UNIT_LOG, 't_initialization, t_simulation,  t_total, n_threads')
  write(message,'(f10.2,2f15.2,i5,a)') time_array(1),time_array(2), &
       &                               time_array(1)+time_array(2), &
       & OMP_GET_MAX_THREADS(), "     #TIMING_REPORT"
  call msg_ez(UNIT_LOG, message)

  ! We do NOT call fftw_cleanup_threads().
  call msg(UNIT_LOG, __FILE__, __LINE__, 'FINISH', 'love && peace && free_software')
  close(unit=UNIT_LOG)
end subroutine feram_common

function basename(fn)
  implicit none
  character(len=FILE_NAME_LEN) :: basename
  character(len=*), intent(in) :: fn
  integer :: len, pos
  len = len_trim(fn)
  pos = index(fn,'/',back=.true.)
  if (pos.gt.0) then
     basename = fn(pos+1:len)
  else
     basename = fn
  end if
end function basename
