! coord_module.F -*-f90-*-
! Time-stamp: <2016-10-25 17:56:39 takeshi>
! Author: Takeshi NISHIMATSU
!!
#if defined HAVE_CONFIG_H
#  include "config.h"
#endif

#include "define.h"

module Coord_module
  use, intrinsic :: iso_c_binding
  implicit none
  type Coord_type
     real*8,     allocatable :: mass_dipo_inv(:,:,:)   ! inverse of mass_dipo
     real*8,     allocatable :: mass_acou_inv(:,:,:)   ! inverse of mass_dipo
     real*8,     allocatable :: dipoRavg(:,:,:,:)
     real*8,     allocatable :: dipoR(:,:,:,:)   ! Optical dipole displacements as a function of R
     complex*16, allocatable :: dipoK(:,:,:,:)   ! FT of dipoR
     logical                 :: relaxor_flag = .false.
     integer,    allocatable :: relaxor(:,:,:)
     real*8,     allocatable :: Z_starR(:,:,:)   ! Z_start(R)
     real*8,     allocatable :: Z_u_R(:,:,:,:)   ! Z_start(R)*u(R)
     complex*16, allocatable :: Z_u_K(:,:,:,:)   ! FT of Z_u_R(:,:,:,:)
     real*8,     allocatable :: dipoP(:,:,:,:)   ! Momenta
     real*8,     allocatable :: dVddi(:,:,:,:)   ! dV/dq for dipole
     real*8,     allocatable :: dVddi_long(:,:,:,:)  ! T for temporary
     complex*16, allocatable :: dipoT(:,:,:,:)   ! Only used in dVddi_dipole_dipole.F
     real*8,     allocatable :: E_field(:,:,:,:) ! external and local electric field
     real*8,     allocatable :: E_field_local(:,:,:,:) ! initial external electric field
     real*8,     allocatable ::  long_range(:,:,:,:,:) ! Fourier transformed potential  !!!REAL*8!!!
     real*8,     allocatable :: short_range(:,:,:,:,:) ! Fourier transformed potential  !!!REAL*8!!!
     real*8,     allocatable :: didiR(:,:,:,:)   ! 6 kind of dipoR*dipoR
     complex*16, allocatable :: didiK(:,:,:,:)   ! 6 kind of dipoR*dipoR
     real*8,     allocatable :: acouR(:,:,:,:)   ! Acoustic displacements in real space
     complex*16, allocatable :: acouK(:,:,:,:)   ! Acoustic displacements
     real*8,     allocatable :: acouP(:,:,:,:)
     real*8,     allocatable :: modulation_R(:,:,:)   ! acoustic modulation
     complex*16, allocatable :: modulation_k(:,:,:)
     complex*16, allocatable :: c_k_modulation_k(:,:,:,:)
     real*8,     allocatable :: inhomo_K(  :,:, :,:,:)     ! FTed potential. See cholesky_d.f in https://gist.github.com/t-nissie/6386f1acc19cd38af621 .
     real*8,     allocatable :: inhomo_K_G(:,:, :,:,:)     ! inhomo_K = G tG, where G is a lower triangular matrix and tG is transpose of G. G(i,4) = 1/G(i,i).
     real*8,     allocatable :: inhomo_coup2_K(:,:, :,:,:) ! FTed potential
     logical,    allocatable :: sum_p(:,:,:) ! .true. if the u(R) is not defect nor mirrored film. This array will be initialized in read_defects_u.F
     real*8,     allocatable :: e_layer_dipo(:)
     real*8,     allocatable :: e_layer_acou(:)
     integer,    allocatable :: n_sum_layer(:)
     real*8                 strain(6)
     real*8                 homogeneous(6,6)
     real*8                 homogeneous_G(6,6)
     real*8                 homogeneous_G_inv(6)
     real*8                 homogeneous_coupling_2(6,6)
     real*8                 s_Nose, pi_Nose, H0! for Nose-Poincare Thermostat
     integer                n_sum_p
     type(C_PTR) ::         inho_ptr = c_null_ptr
     type(C_PTR) ::         dVdac_ptr = c_null_ptr
     ! These plans are odered as in feram_fftw_wisdom.F.
     type(C_PTR) ::         plan_r2c_1_out = c_null_ptr   ! will be made with FFTW_ESTIMATE, used in elastic.F once
     type(C_PTR) ::         plan_c2r_3_in  = c_null_ptr   ! dVdacK->dVdacR (dVdac.F)
     type(C_PTR) ::         plan_c2r_6_in  = c_null_ptr   ! inhoK->inhoR (dVddi_inho_coupling.F)
     type(C_PTR) ::         plan_r2c_3_out = c_null_ptr   ! dipoR->dipoK (dipoFFT.F), acouR->acouK (acouFFT.F)
     type(C_PTR) ::         plan_c2r_3_out = c_null_ptr   ! dipoT->dVddi (dVddi-dipole-dipole.F), acouK->acouR (write_system(). It is not crucial for speed.)
     type(C_PTR) ::         plan_r2c_6_out = c_null_ptr   ! didiR->didiK (dipoFFT.F)
  end type Coord_type

contains
  subroutine alloc_Coord(p,c)
    use, intrinsic :: iso_c_binding
    use Param_module
    use msg_module
    implicit none
    type(Param_type), intent(in)    :: p
    type(Coord_type), intent(inout) :: c
    integer ix,iy,iz

    include 'fftw3.f03'
    integer howmany,stride
    integer, parameter :: rank=3
    integer, parameter :: dist=1
    integer  LzLyLx(3)
    integer d_embed(3)
    integer z_embed(3)

    integer(C_SIZE_T) :: n_alloc
    complex*16,pointer :: dVdacK(:,:,:,:)
    real*8,    pointer :: dVdacR(:,:,:,:)
    complex*16,pointer ::  inhoK(:,:,:,:)
    real*8,    pointer ::  inhoR(:,:,:,:)
    real*8 mass_inv_tmp

    LzLyLx( 1)=p%Lz; LzLyLx( 2)=p%Ly; LzLyLx( 3)=p%Lx    ! p%padding_y will be introduced.
    d_embed(1)=p%Lz; d_embed(2)=p%Ly+p%padding_y; d_embed(3)=2*(p%Lx/2+1)
    z_embed(1)=p%Lz; z_embed(2)=p%Ly+p%padding_y; z_embed(3)=p%Lx/2+1
    call fftw_destroy_plan(c%plan_r2c_3_out)
    call fftw_destroy_plan(c%plan_r2c_6_out)   ! It is safe to destroy c_null_ptr.
    call fftw_destroy_plan(c%plan_c2r_6_in )   ! See fftw3/api/apiplan.c.
    call fftw_destroy_plan(c%plan_c2r_3_out)

    call msg(UNIT_LOG, __FILE__, __LINE__, 'BEGIN', 'alloc_Coord().')
    !--- mass_dipo_inv ------------------------------
    if (allocated(c%mass_dipo_inv)) deallocate(c%mass_dipo_inv)
    allocate(c%mass_dipo_inv(0:2*(p%Lx/2+1)-1, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
  !!!first touch
!$omp parallel do
    do iz = 0,p%Lz-1
       c%mass_dipo_inv(:,:,iz) = 0.0d0
    end do
!$omp end parallel do
    mass_inv_tmp = 1.0d0 / p%mass_dipo(1)
!$omp parallel do
    do iz = 0,p%Lz-1
       c%mass_dipo_inv(0:p%Lx-1, 0:p%Ly-1, iz) = mass_inv_tmp
    end do
!$omp end parallel do

    !--- mass_acou_inv ------------------------------
    if (allocated(c%mass_acou_inv)) deallocate(c%mass_acou_inv)
    allocate(c%mass_acou_inv(0:2*(p%Lx/2+1)-1, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
  !!!first touch
!$omp parallel do
    do iz = 0,p%Lz-1
       c%mass_acou_inv(:,:,iz) = 0.0d0
    end do
!$omp end parallel do
    mass_inv_tmp = 1.0d0 / p%mass_acou(1)
!$omp parallel do
    do iz = 0,p%Lz-1
       c%mass_acou_inv(0:p%Lx-1, 0:p%Ly-1, iz) = mass_inv_tmp
    end do
!$omp end parallel do

    !--- dipoRavg ---------------------------
    if (allocated(c%dipoRavg)) deallocate(c%dipoRavg)
    allocate(     c%dipoRavg(3, 0:2*(p%Lx/2+1)-1, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
    ! First touch and reset will be done in molecular-dynamics.F

    !--- dipo -------------------------------
    if (allocated(c%dipoR)) deallocate(c%dipoR)
    allocate(     c%dipoR(3, 0:2*(p%Lx/2+1)-1, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
    if (allocated(c%dipoK)) deallocate(c%dipoK)
    allocate(     c%dipoK(3, 0:p%Lx/2, 0:p%Ly+p%padding_y-1, 0:p%Lz-1)) !"/2" for real<->complex FFT
  !!!first touch
!$omp parallel do
    do iz = 0,p%Lz-1
       c%dipoR(:,:,:,iz) = 0.0d0
    end do
!$omp end parallel do
!$omp parallel do
    do iz = 0,p%Lz-1
       c%dipoK(:,:,:,iz) = (0.0d0,0.0d0)
    end do
!$omp end parallel do
    howmany = 3
    stride = howmany
    c%plan_r2c_3_out = fftw_plan_many_dft_r2c(rank,LzLyLx,howmany,&
         &                                  c%dipoR,d_embed,stride,dist,&
         &                                  c%dipoK,z_embed,stride,dist,FFTW_MEASURE)

    !--- relaxor -------------------------------
    if (allocated(c%relaxor)) deallocate(c%relaxor)
    allocate(     c%relaxor(0:2*(p%Lx/2+1)-1, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
!$omp parallel do
    do iz = 0,p%Lz-1
       c%relaxor(:,:,iz) = 1
    end do
!$omp end parallel do

    !--- Z_star(R) -------------------------------
    if (allocated(c%Z_starR)) deallocate(c%Z_starR)
    allocate(     c%Z_starR(0:2*(p%Lx/2+1)-1, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
!$omp parallel do
    do iz = 0,p%Lz-1
       c%Z_starR(:,:,iz) = 0.0d0   ! It may be important that the padding area is 0.0d0.
    end do
!$omp end parallel do
!$omp parallel do
    do iz = 0,p%Lz-1
       do iy=0, p%Ly-1
          do ix=0, p%Lx-1
             c%Z_starR(ix,iy,iz) = p%Z_star(1)
          end do
       end do
    end do
!$omp end parallel do

    !--- Z(R)*u(R) -------------------------------
    if (allocated(c%Z_u_R)) deallocate(c%Z_u_R)
    allocate(     c%Z_u_R(3, 0:2*(p%Lx/2+1)-1, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
    if (allocated(c%Z_u_K)) deallocate(c%Z_u_K)
    allocate(     c%Z_u_K(3, 0:p%Lx/2, 0:p%Ly+p%padding_y-1, 0:p%Lz-1)) !"/2" for real<->complex FFT
  !!!first touch
!$omp parallel do
    do iz = 0,p%Lz-1
       c%Z_u_R(:,:,:,iz) = 0.0d0
    end do
!$omp end parallel do
!$omp parallel do
    do iz = 0,p%Lz-1
       c%Z_u_K(:,:,:,iz) = (0.0d0,0.0d0)
    end do
!$omp end parallel do

    if (allocated(c%dipoP)) deallocate(c%dipoP)
    allocate(     c%dipoP(3, 0:2*(p%Lx/2+1)-1, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
    if (allocated(c%dVddi)) deallocate(c%dVddi)
    allocate(     c%dVddi(3, 0:2*(p%Lx/2+1)-1, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
    if (allocated(c%dVddi_long)) deallocate(c%dVddi_long)
    allocate(c%dVddi_long(3, 0:2*(p%Lx/2+1)-1, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
    if (allocated(c%dipoT)) deallocate(c%dipoT)
    allocate(     c%dipoT(3, 0:p%Lx/2, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
  !!!first touch
!$omp parallel do
    do iz = 0,p%Lz-1
       c%dVddi(:,:,:,iz) = 0.0d0
    end do
!$omp end parallel do
!$omp parallel do
    do iz = 0,p%Lz-1
       c%dVddi_long(:,:,:,iz) = 0.0d0
    end do
!$omp end parallel do
!$omp parallel do
    do iz = 0,p%Lz-1
       c%dipoT(:,:,:,iz) = (0.0d0,0.0d0)
    end do
!$omp end parallel do

    if (allocated(c%E_field)) deallocate(c%E_field)
    allocate(     c%E_field(3, 0:2*(p%Lx/2+1)-1, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
  !!!first touch
!$omp parallel do
    do iz = 0,p%Lz-1
       c%E_field(:,:,:,iz) = 0.0d0
    end do
!$omp end parallel do

    if (allocated(c%E_field_local)) deallocate(c%E_field_local)
    allocate(     c%E_field_local(3, 0:2*(p%Lx/2+1)-1, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
  !!!first touch
!$omp parallel do
    do iz = 0,p%Lz-1
       c%E_field_local(:,:,:,iz) = 0.0d0
    end do
!$omp end parallel do

    if (allocated(c%long_range)) deallocate(c%long_range)
    allocate(     c%long_range(3, 3, 0:p%Lx/2, 0:p%Ly+p%padding_y-1, 0:p%Lz-1)) !"/2" for real<->complex FFT
  !!!first touch
!$omp parallel do
    do iz = 0,p%Lz-1
       c%long_range(:,:, :,:,iz) = 0.0d0
    end do
!$omp end parallel do

    if (allocated(c%short_range)) deallocate(c%short_range)
    allocate(     c%short_range(3, 3, 0:p%Lx/2, 0:p%Ly+p%padding_y-1, 0:p%Lz-1)) !"/2" for real<->complex FFT
  !!!first touch
!$omp parallel do
    do iz = 0,p%Lz-1
       c%short_range(:,:, :,:,iz) = 0.0d0
    end do
!$omp end parallel do

    if (allocated(c%didiR)) deallocate(c%didiR)
    allocate(     c%didiR(6, 0:2*(p%Lx/2+1)-1, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
    if (allocated(c%didiK)) deallocate(c%didiK)
    allocate(     c%didiK(6, 0:p%Lx/2, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))    !"/2" for real<->complex FFT
  !!!first touch
!$omp parallel do
    do iz = 0,p%Lz-1
       c%didiR(:,:,:,iz) = 0.0d0
    end do
!$omp end parallel do
!$omp parallel do
    do iz = 0,p%Lz-1
       c%didiK(:,:,:,iz) = (0.0d0,0.0d0)
    end do
!$omp end parallel do
    howmany = 6
    stride = howmany
    c%plan_r2c_6_out = fftw_plan_many_dft_r2c(rank,LzLyLx,howmany,&
         &                                  c%didiR,d_embed,stride,dist,&
         &                                  c%didiK,z_embed,stride,dist,FFTW_MEASURE)

    !--- acou -------------------------------
    if (allocated(c%acouR)) deallocate(c%acouR)
    allocate(c%acouR(3, 0:2*(p%Lx/2+1)-1, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
    if (allocated(c%acouK)) deallocate(c%acouK)
    allocate(c%acouK(3, 0:p%Lx/2, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
    if (allocated(c%acouP)) deallocate(c%acouP)
    allocate(c%acouP(3, 0:2*(p%Lx/2+1)-1, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
  !!!first touch
!$omp parallel do
    do iz = 0,p%Lz-1
       c%acouR(:,:,:,iz) = 0.0d0
    end do
!$omp end parallel do
!$omp parallel do
    do iz = 0,p%Lz-1
       c%acouK(:,:,:,iz) = (0.0d0,0.0d0)
    end do
!$omp end parallel do
!$omp parallel do
    do iz = 0,p%Lz-1
       c%acouP(:,:,:,iz) = 0.0d0
    end do
!$omp end parallel do
    howmany = 3
    stride = howmany
    c%plan_c2r_3_out = fftw_plan_many_dft_c2r(rank,LzLyLx,howmany,&
         &                                  c%acouK,z_embed,stride,dist,&
         &                                  c%acouR,d_embed,stride,dist,FFTW_MEASURE)

    !--- modulation -------------------------------
    if (allocated(c%modulation_R)) deallocate(c%modulation_R)
    allocate(c%modulation_R(0:2*(p%Lx/2+1)-1, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
    if (allocated(c%modulation_k)) deallocate(c%modulation_k)
    allocate(c%modulation_k(        0:p%Lx/2, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
    if (allocated(c%c_k_modulation_k)) deallocate(c%c_k_modulation_k)
    allocate(c%c_k_modulation_k(3,  0:p%Lx/2, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
  !!!first touch
!$omp parallel do
    do iz = 0,p%Lz-1
       c%modulation_R(:,:,iz) = 0.0d0
    end do
!$omp end parallel do
!$omp parallel do
    do iz = 0,p%Lz-1
       c%modulation_k(:,:,iz) = (0.0d0,0.0d0)
    end do
!$omp end parallel do
!$omp parallel do
    do iz = 0,p%Lz-1
       c%c_k_modulation_k(:,:,:,iz) = (0.0d0,0.0d0)
    end do
!$omp end parallel do
    howmany = 1
    stride = howmany
    c%plan_r2c_1_out = fftw_plan_many_dft_r2c(rank,LzLyLx,howmany,&
         &                                    c%modulation_R,d_embed,stride,dist,&
         &                                    c%modulation_k,z_embed,stride,dist,FFTW_ESTIMATE)

    !--- force on acoustic displacement --------
    howmany = 3
    if (c_associated(c%dVdac_ptr)) call fftw_free(c%dVdac_ptr)
    n_alloc = howmany * (p%Lx/2+1) * (p%Ly+p%padding_y) * p%Lz
    c%dVdac_ptr = fftw_malloc(n_alloc * 16)   ! 16 for complex*16
    call c_f_pointer(c%dVdac_ptr, dVdacK, [howmany,   (p%Lx/2+1), p%Ly+p%padding_y, p%Lz])
    call c_f_pointer(c%dVdac_ptr, dVdacR, [howmany, 2*(p%Lx/2+1), p%Ly+p%padding_y, p%Lz])
!!!first touch!!! Here, indexes of arrays do not have to start from 0. It is simpler than dVddi_inho_coupling.F.
!$omp parallel do
    do iz = 1, p%Lz
       dVdacK(:,:,:,iz) = (0.0d0,0.0d0)
    end do
!$omp end parallel do
    stride = howmany
    c%plan_c2r_3_in = fftw_plan_many_dft_c2r(rank,LzLyLx,howmany,&
         &                                   dVdacK,z_embed,stride,dist,&
         &                                   dVdacR,d_embed,stride,dist,FFTW_MEASURE)

    !--- inhomogeneous strain ---------------
    howmany = 6
    if (c_associated(c%inho_ptr)) call fftw_free(c%inho_ptr)
    n_alloc = howmany * (p%Lx/2+1) * (p%Ly+p%padding_y) * p%Lz
    c%inho_ptr = fftw_malloc(n_alloc * 16)   ! 16 for complex*16
    call c_f_pointer(c%inho_ptr, inhoK, [howmany,   (p%Lx/2+1), p%Ly+p%padding_y, p%Lz])
    call c_f_pointer(c%inho_ptr, inhoR, [howmany, 2*(p%Lx/2+1), p%Ly+p%padding_y, p%Lz])
!!!first touch!!! Here, indexes of arrays do not have to start from 0. It is simpler than dVddi_inho_coupling.F.
!$omp parallel do
    do iz = 1, p%Lz
       inhoK(:,:,:,iz) = (0.0d0,0.0d0)
    end do
!$omp end parallel do
    stride = howmany
    c%plan_c2r_6_in = fftw_plan_many_dft_c2r(rank,LzLyLx,howmany,&
         &                                   inhoK,z_embed,stride,dist,&
         &                                   inhoR,d_embed,stride,dist,FFTW_MEASURE)

    if (allocated(c%inhomo_K)) deallocate(c%inhomo_K)
    allocate(     c%inhomo_K(3,3, 0:p%Lx/2,0:p%Ly+p%padding_y-1,0:p%Lz-1))

    if (allocated(c%inhomo_K_G)) deallocate(c%inhomo_K_G)
    allocate(     c%inhomo_K_G(3,4, 0:p%Lx/2,0:p%Ly+p%padding_y-1,0:p%Lz-1))

    if (allocated(c%inhomo_coup2_K)) deallocate(c%inhomo_coup2_K)
    allocate(c%inhomo_coup2_K(3,6, 0:p%Lx/2,0:p%Ly+p%padding_y-1  ,0:p%Lz-1))

  !!!first touch
!$omp parallel do
    do iz = 0,p%Lz-1
       c%inhomo_K(:,:, :,:,iz) = 0.0d0
    end do
!$omp end parallel do
!$omp parallel do
    do iz = 0,p%Lz-1
       c%inhomo_K_G(:,:, :,:,iz) = 0.0d0
    end do
!$omp end parallel do
!$omp parallel do
    do iz = 0,p%Lz-1
       c%inhomo_coup2_K(:,:, :,:,iz) = 0.0d0
    end do
!$omp end parallel do

    !--- sum_p ------------------------------
    if (allocated(c%sum_p)) deallocate(c%sum_p)
    allocate(c%sum_p(0:2*(p%Lx/2+1)-1, 0:p%Ly+p%padding_y-1, 0:p%Lz-1))
  !!!first touch
!$omp parallel do
    do iz = 0,p%Lz-1
       c%sum_p(:,:,iz) = .false.
    end do
!$omp end parallel do

    !--- e_layer_dipo and e_layer_and for thermal conductivity----
    if (allocated(c%e_layer_dipo)) deallocate(c%e_layer_dipo)
    allocate(c%e_layer_dipo(0:p%Lz-1))
    if (allocated(c%e_layer_acou)) deallocate(c%e_layer_acou)
    allocate(c%e_layer_acou(0:p%Lz-1))
    if (allocated(c%n_sum_layer)) deallocate(c%n_sum_layer)
    allocate(c%n_sum_layer(0:p%Lz-1))
  !!!first touch
!$omp parallel do
    do iz = 0,p%Lz-1
       c%e_layer_dipo(iz) = 0.0d0
       c%e_layer_acou(iz) = 0.0d0
       c%n_sum_layer( iz) = p%Lx * p%Ly
    end do
!$omp end parallel do
    !--- end --------------------------------
    call msg(UNIT_LOG, __FILE__, __LINE__, 'END', ' alloc_Coord().')
  end subroutine alloc_Coord

  subroutine write_system(p,c,fn)
    use, intrinsic :: iso_c_binding
    use Param_module
    use msg_module
    implicit none
    type(Param_type), intent(in) :: p
    type(Coord_type), intent(inout) :: c
    character(len=*) :: fn
    character(len=FILE_NAME_LEN) :: coord_directory_fn
    integer alpha,ix,iy,iz
    include 'fftw3.f03'

    call msg(UNIT_LOG, __FILE__, __LINE__, 'BEGIN', 'write_system().')

    if (p%coord_directory.eq.'never') then
       call msg(UNIT_LOG, __FILE__, __LINE__, 'END', 'never write .coord files.')
       return
    else if (p%coord_directory.eq.'') then
       coord_directory_fn = trim(fn)
    else
       coord_directory_fn = trim(p%coord_directory) // '/' // trim(fn)
    end if

    if (p%mass_acou(1) <= 0.0d0) then
!$omp parallel do
       do iz = 0,p%Lz-1
          c%acouK(:,:,:,iz) = (0.0d0, -1.0d0) * c%acouK(:,:,:,iz)
       end do
!$omp end parallel do
       call fftw_execute_dft_c2r(c%plan_c2r_3_out, c%acouK, c%acouR)
!$omp parallel do
       do iz = 0,p%Lz-1
          c%acouR(:,:,:,iz) = c%acouR(:,:,:,iz) * p%Ninv
       end do
!$omp end parallel do
    end if

    open(unit=UNIT_SYSTEM, file=coord_directory_fn, status='replace')
    do iz = 0, p%Lz-1
       do iy = 0, p%Ly-1
          do ix = 0, p%Lx-1
             write(UNIT_SYSTEM,'(i4,2i5,3f10.6,9e14.6,3f13.6)') ix, iy, iz, &
                  & (c%dipoR(alpha,ix,iy,iz)         ,alpha=1,3),&
                  & (c%dipoP(alpha,ix,iy,iz)/c%s_Nose,alpha=1,3),&
                  & (c%dVddi(alpha,ix,iy,iz)         ,alpha=1,3),&
                  & (c%acouR(alpha,ix,iy,iz)         ,alpha=1,3),&
                  & (c%acouP(alpha,ix,iy,iz)         ,alpha=1,3)
          end do
       end do
    end do
    close(UNIT_SYSTEM)
    call msg(UNIT_LOG, __FILE__, __LINE__, 'END', trim(coord_directory_fn)//' was written.')
  end subroutine write_system

  subroutine write_slice(p,c,fn)
    use Param_module
    use msg_module
    implicit none
    type(Param_type), intent(in) :: p
    type(Coord_type), intent(inout) :: c
    character(len=*) :: fn
    character(len=FILE_NAME_LEN) :: slice_directory_fn
    integer ix,iy
    integer, parameter :: X_OFFSET =  50
    integer, parameter :: Y_OFFSET =  50
    integer, parameter :: X_WIDTH  =  10
    integer, parameter :: Y_HEIGHT =  10

    call msg(UNIT_LOG, __FILE__, __LINE__, 'BEGIN', 'write_slice().')

    if (p%slice_directory.eq.'never') then
       call msg(UNIT_LOG, __FILE__, __LINE__, 'END', 'never write .slice.eps files.')
       return
    else if (p%slice_directory.eq.'') then
       slice_directory_fn = trim(fn)
    else
       slice_directory_fn = trim(p%slice_directory) // '/' // trim(fn)
    end if

    open(unit=UNIT_SYSTEM, file=slice_directory_fn, status='replace')

    write(UNIT_SYSTEM,'(a)') '%!PS-Adobe-2.0 EPSF-2.0'
    write(UNIT_SYSTEM,'(a,2i3,2i6)') '%%BoundingBox:', X_OFFSET, Y_OFFSET, X_OFFSET+X_WIDTH * p%Lx, &
         &                                                                 Y_OFFSET+Y_HEIGHT* p%Ly
    write(UNIT_SYSTEM,'(a)') '%%Creator: feram (src/coord_module.F) by Takeshi NISHIMATSU'
    write(UNIT_SYSTEM,'(a)') '%%Orientation: Portrait'
    write(UNIT_SYSTEM,'(a,a)') '%%Title: ', trim(slice_directory_fn)
    write(UNIT_SYSTEM,'(a)') '%%EndComments'
    write(UNIT_SYSTEM,'(a,i3,a)') '/x_offset ',  X_OFFSET, ' def'
    write(UNIT_SYSTEM,'(a,i3,a)') '/y_offset ',  Y_OFFSET, ' def'
    write(UNIT_SYSTEM,'(a,i3,a)') '/x_width   ', X_WIDTH,  ' def'
    write(UNIT_SYSTEM,'(a,i3,a)') '/y_height  ', Y_HEIGHT, ' def'
    write(UNIT_SYSTEM,'(a)') '/LineWidth   1 def'
    write(UNIT_SYSTEM,'(a)') '/LineWidth20 LineWidth 2.0 mul def'
    write(UNIT_SYSTEM,'(a)') '/LineWidth15 LineWidth 1.5 mul def'
    write(UNIT_SYSTEM,'(a)') '/LineWidth05 LineWidth 0.5 mul def'
    write(UNIT_SYSTEM,'(a)') ''
    write(UNIT_SYSTEM,'(a)') '/Up {'
    write(UNIT_SYSTEM,'(a)') ' newpath'
    write(UNIT_SYSTEM,'(a)') '  exch'
    write(UNIT_SYSTEM,'(a)') '  x_width  mul x_offset add'
    write(UNIT_SYSTEM,'(a)') '  exch'
    write(UNIT_SYSTEM,'(a)') '  y_height mul y_offset add'
    write(UNIT_SYSTEM,'(a)') '  moveto'
    write(UNIT_SYSTEM,'(a)') '  LineWidth dup rmoveto'
    write(UNIT_SYSTEM,'(a)') '  x_width LineWidth20 sub     0 rlineto'
    write(UNIT_SYSTEM,'(a)') '  0    y_height LineWidth20 sub rlineto'
    write(UNIT_SYSTEM,'(a)') '  x_width LineWidth20 sub neg 0 rlineto'
    write(UNIT_SYSTEM,'(a)') ' closepath'
    write(UNIT_SYSTEM,'(a)') ' 1 0 0 setrgbcolor'
    write(UNIT_SYSTEM,'(a)') ' LineWidth setlinewidth'
    write(UNIT_SYSTEM,'(a)') ' stroke'
    write(UNIT_SYSTEM,'(a)') '} def'
    write(UNIT_SYSTEM,'(a)') ''
    write(UNIT_SYSTEM,'(a)') '/Down {'
    write(UNIT_SYSTEM,'(a)') ' newpath'
    write(UNIT_SYSTEM,'(a)') '  exch'
    write(UNIT_SYSTEM,'(a)') '  x_width  mul x_offset add'
    write(UNIT_SYSTEM,'(a)') '  exch'
    write(UNIT_SYSTEM,'(a)') '  y_height mul y_offset add'
    write(UNIT_SYSTEM,'(a)') '  moveto'
    write(UNIT_SYSTEM,'(a)') '  LineWidth05 dup rmoveto'
    write(UNIT_SYSTEM,'(a)') '  x_width LineWidth sub     0 rlineto'
    write(UNIT_SYSTEM,'(a)') '  0    y_height LineWidth sub rlineto'
    write(UNIT_SYSTEM,'(a)') '  x_width LineWidth sub neg 0 rlineto'
    write(UNIT_SYSTEM,'(a)') '  closepath'
    write(UNIT_SYSTEM,'(a)') '  0 0 1 setrgbcolor fill'
    write(UNIT_SYSTEM,'(a,/)') '} def'

    do iy = 0, p%Ly-1
       do ix = 0, p%Lx-1
          if (c%dipoR(3,ix,iy,p%Lz/4)<=0.0d0) then
             write(UNIT_SYSTEM,'(i4,i5,a)') ix, iy, ' Down'
          else
             write(UNIT_SYSTEM,'(i4,i5,a)') ix, iy, ' Up'
          end if
       end do
    end do

    write(UNIT_SYSTEM,'(/,a)') 'showpage'
    close(UNIT_SYSTEM)
    call msg(UNIT_LOG, __FILE__, __LINE__, 'END', trim(slice_directory_fn)//' was written.')
  end subroutine write_slice

  subroutine divide_and_write_dipoRavg(p,c)
    use Param_module
    use msg_module
    implicit none
    type(Param_type), intent(in) :: p
    type(Coord_type), intent(in) :: c
    character(len=FILE_NAME_LEN) :: fn
    integer ix,iy,iz,alpha
    call msg(UNIT_LOG, __FILE__, __LINE__, 'BEGIN', 'divide_and_write_dipoRavg().')

    if (p%coord_directory.eq.'never') then
       call msg(UNIT_LOG, __FILE__, __LINE__, 'END', &
            & '  divide_and_write_dipoRavg(): '//trim(p%filename)//'.dipoRavg was NOT written.')
       return
    else if (p%coord_directory.eq.'') then
       fn = trim(p%filename) // '.dipoRavg'
    else
       fn = trim(p%coord_directory) // trim(p%filename) // '.dipoRavg'
    end if

    open(unit=UNIT_SYSTEM, file=fn, status='replace')
    do iz = 0, p%Lz-1
       do iy = 0, p%Ly-1
          do ix = 0, p%Lx-1
             write(UNIT_SYSTEM,'(i4,2i5,3f10.6)') ix, iy, iz, &
                  & (c%dipoRavg(alpha,ix,iy,iz)/p%n_average, alpha=1,3)
          end do
       end do
    end do
    close(UNIT_SYSTEM)

    call msg(UNIT_LOG, __FILE__, __LINE__, 'END', &
         & '  divide_and_write_dipoRavg(): '//trim(fn)//' was written.')
  end subroutine divide_and_write_dipoRavg

  subroutine write_fft(p,c,fn)
    use Param_module
    use msg_module
    implicit none
    type(Param_type), intent(in) :: p
    type(Coord_type), intent(in) :: c
    character(len=*) :: fn
    integer ix,iy,yy

    call msg(UNIT_LOG, __FILE__, __LINE__, 'BEGIN', 'write_fft().')
    open(unit=UNIT_SYSTEM,file=fn)
    do iy= -p%Ly/2, p%Ly/2
       if (iy<0) then
          yy=p%Ly+iy
       else
          yy=iy
       end if
       do ix=0, p%Lx/2
          write(UNIT_SYSTEM,*) abs(c%dipoK(3,ix,yy,0)), c%dipoK(3,ix,yy,0)
       end do
       write(UNIT_SYSTEM,*) ''
    end do
    close(UNIT_SYSTEM)
    call msg(UNIT_LOG, __FILE__, __LINE__, 'FILENAME', fn)
    call msg(UNIT_LOG, __FILE__, __LINE__, 'END', '  write_fft().')
  end subroutine write_fft
end module Coord_module
