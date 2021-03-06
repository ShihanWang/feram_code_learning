! dipoFFT.F -*-f90-*-
! Time-stamp: <2016-06-25 16:48:00 takeshi>
! Author: Takeshi NISHIMATSU
!!
#if defined HAVE_CONFIG_H
#  include "config.h"
#endif
#include "define.h"
subroutine dipoFFT(p,c)
  use Param_module
  use Coord_module
  use msg_module
  implicit none
  type(Param_type),  intent(in)    :: p
  type(Coord_type),  intent(inout) :: c
  integer ix,iy,iz
  include 'fftw3.f03'
  if (p%verbose>=4) call msg(UNIT_LOG, __FILE__, __LINE__, 'BEGIN', 'dipoFFT(): dipoR -> dipoK, didiR, didiK.')
  call fftw_execute_dft_r2c(c%plan_r2c_3_out, c%dipoR, c%dipoK)
!$omp parallel do private(iz, iy, ix)
  do iz=0, p%Lz-1
     do iy = 0, p%Ly-1
        do ix = 0, p%Lx-1
           c%didiR(1,ix,iy,iz) = c%dipoR(1,ix,iy,iz) * c%dipoR(1,ix,iy,iz)
           c%didiR(2,ix,iy,iz) = c%dipoR(2,ix,iy,iz) * c%dipoR(2,ix,iy,iz)
           c%didiR(3,ix,iy,iz) = c%dipoR(3,ix,iy,iz) * c%dipoR(3,ix,iy,iz)
           c%didiR(4,ix,iy,iz) = c%dipoR(2,ix,iy,iz) * c%dipoR(3,ix,iy,iz)
           c%didiR(5,ix,iy,iz) = c%dipoR(3,ix,iy,iz) * c%dipoR(1,ix,iy,iz)
           c%didiR(6,ix,iy,iz) = c%dipoR(1,ix,iy,iz) * c%dipoR(2,ix,iy,iz)
        end do
     end do
  end do
!$omp end parallel do
  call fftw_execute_dft_r2c(c%plan_r2c_6_out, c%didiR, c%didiK)
!$omp parallel do
    do iz = 0,p%Lz-1
       do iy=0, p%Ly-1
          do ix=0, p%Lx-1
             c%Z_u_R(:,ix,iy,iz) = c%Z_starR(ix,iy,iz) * c%dipoR(:,ix,iy,iz)
          end do
       end do
    end do
!$omp end parallel do
  call fftw_execute_dft_r2c(c%plan_r2c_3_out, c%Z_u_R, c%Z_u_K)
  if (p%verbose>=4) call msg(UNIT_LOG, __FILE__, __LINE__, 'END', &
          & '  dipoFFT(): didiR will be used in optimize-*-strain.F and dVddi-unharmonic.F.')
end subroutine dipoFFT
