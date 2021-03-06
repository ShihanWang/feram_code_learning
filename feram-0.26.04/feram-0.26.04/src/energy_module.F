! energy_module.F -*-f90-*-
! Time-stamp: <2016-06-09 22:35:29 takeshi>
! Author: Takeshi NISHIMATSU
!!
module Energy_module
  implicit none
  type Energy_type
                              ! calculated in
     real*8 acou_kinetic      ! leapfrog.F or nose-poincare.F, initialize in initialize_dipoR.F
     real*8 dipo_kinetic      ! leapfrog.F or nose-poincare.F, initialize in initialize_dipoR.F
     real*8 short_range       ! dVddi-dipole-dipole.F
     real*8 long_range        ! dVddi-dipole-dipole.F
     real*8 dipole_E_field    ! -m.E, dVddi_E_field.F
     real*8 unharmonic        ! dVddi-unharmonic.F
     real*8 homo_strain       ! optimize-homo-strain.F
     real*8 homo_coupling     ! optimize-homo-strain.F
     real*8 inho_strain       ! optimize-inho-strain.F
     real*8 inho_coupling     ! optimize-inho-strain.F
     real*8 inho_modulation   ! optimize-inho-strain.F
     real*8 total

     real*8 H_Nose_Poincare
  end type Energy_type
!
interface operator(+)
   module procedure add_Energy
end interface

contains
  function add_Energy(a,b)
    implicit none
    type(Energy_type)             :: add_Energy
    type(Energy_type), intent(in) :: a, b

    add_Energy%acou_kinetic    = a%acou_kinetic    + b%acou_kinetic
    add_Energy%dipo_kinetic    = a%dipo_kinetic    + b%dipo_kinetic
    add_Energy%short_range     = a%short_range     + b%short_range
    add_Energy%long_range      = a%long_range      + b%long_range
    add_Energy%dipole_E_field  = a%dipole_E_field  + b%dipole_E_field
    add_Energy%unharmonic      = a%unharmonic      + b%unharmonic
    add_Energy%homo_strain     = a%homo_strain     + b%homo_strain
    add_Energy%homo_coupling   = a%homo_coupling   + b%homo_coupling
    add_Energy%inho_strain     = a%inho_strain     + b%inho_strain
    add_Energy%inho_coupling   = a%inho_coupling   + b%inho_coupling
    add_Energy%inho_modulation = a%inho_modulation + b%inho_modulation
    add_Energy%total           = a%total           + b%total

    add_Energy%H_Nose_Poincare = a%H_Nose_Poincare + b%H_Nose_Poincare
  end function add_Energy

  function div_Energy(a,n)
    implicit none
    type(Energy_type)             :: div_Energy
    type(Energy_type), intent(in) :: a
    integer, intent(in)           :: n

    div_Energy%acou_kinetic    = a%acou_kinetic    / n
    div_Energy%dipo_kinetic    = a%dipo_kinetic    / n
    div_Energy%short_range     = a%short_range     / n
    div_Energy%long_range      = a%long_range      / n
    div_Energy%dipole_E_field  = a%dipole_E_field  / n
    div_Energy%unharmonic      = a%unharmonic      / n
    div_Energy%homo_strain     = a%homo_strain     / n
    div_Energy%homo_coupling   = a%homo_coupling   / n
    div_Energy%inho_strain     = a%inho_strain     / n
    div_Energy%inho_coupling   = a%inho_coupling   / n
    div_Energy%inho_modulation = a%inho_modulation / n
    div_Energy%total           = a%total           / n

    div_Energy%H_Nose_Poincare = a%H_Nose_Poincare / n
  end function div_Energy

  function sum_potential_energies(e)
    implicit none
    real*8 :: sum_potential_energies
    type(Energy_type), intent(in) :: e
    sum_potential_energies &
         = e%short_range   &
         + e%long_range    &
         + e%dipole_E_field&
         + e%unharmonic    &
         + e%homo_strain   &
         + e%homo_coupling &
         + e%inho_strain   &
         + e%inho_coupling &
         + e%inho_modulation
  end function sum_potential_energies

  subroutine write_Energy(p,c,e,fd)
    use Param_module
    use Coord_module
    use msg_module
    implicit none
    !--- arguments -------------------------------------
    type(Param_type),  intent(in)    :: p
    type(Coord_type),  intent(inout) :: c
    type(Energy_type), intent(inout) :: e
    integer fd
    !--- local -----------------------------------------
    character(30), parameter :: fmt = "(a15,f18.12,' [eV/u.c.]')"
    character(45) message
    !--- END of variable definitions -------------------

    write(message,fmt) 'acou_kinetic   ', e%acou_kinetic*p%Ninv;    call msg_ez(fd,message)
    write(message,fmt) 'dipo_kinetic   ', e%dipo_kinetic/c%s_Nose**2*p%Ninv
                                                                    call msg_ez(fd,message)
    write(message,fmt) 'short_range    ', e%short_range*p%Ninv;     call msg_ez(fd,message)
    write(message,fmt) 'long_range     ', e%long_range*p%Ninv;      call msg_ez(fd,message)
    write(message,fmt) 'dipole_E_field ', e%dipole_E_field*p%Ninv;  call msg_ez(fd,message)
    write(message,fmt) 'unharmonic     ', e%unharmonic*p%Ninv;      call msg_ez(fd,message)
    write(message,fmt) 'homo_strain    ', e%homo_strain*p%Ninv;     call msg_ez(fd,message)
    write(message,fmt) 'homo_coupling  ', e%homo_coupling*p%Ninv;   call msg_ez(fd,message)
    write(message,fmt) 'inho_strain    ', e%inho_strain*p%Ninv;     call msg_ez(fd,message)
    write(message,fmt) 'inho_coupling  ', e%inho_coupling*p%Ninv;   call msg_ez(fd,message)
    write(message,fmt) 'inho_modulation', e%inho_modulation*p%Ninv; call msg_ez(fd,message)
    call msg_ez(fd,'--------------------------------------------')
    write(message,fmt) 'total_energy   ', e%total*p%Ninv;           call msg_ez(fd,message)

    if (p%method.eq.'md') then
       write(message,fmt) 'H_Nose_Poincare', e%H_Nose_Poincare*p%Ninv; call msg_ez(fd,message)
       write(message,'(a7,f14.8,a9,f14.8)') 's_Nose=', c%s_Nose, ' pi_Nose=', c%pi_Nose
       call msg_ez(fd,message)
    end if

    flush(fd)
  end subroutine write_Energy

  subroutine Nose_Poincare_Hamiltonian(p,c,e)
    use Param_module
    use Coord_module
    implicit none
    !--- arguments -------------------------------------
    type(Param_type),  intent(in)    :: p
    type(Coord_type),  intent(inout) :: c
    type(Energy_type), intent(out)   :: e
    !--- local -----------------------------------------
    !real*8 total
    !character(30), parameter :: fmt = "(a14,f16.10,' [eV/u.c.]')"
    !character(45) message
    !--- END of variable definitions -------------------
    e%H_Nose_Poincare &
         = e%dipo_kinetic / c%s_Nose**2 &
         + sum_potential_energies(e) &
         + c%pi_Nose**2/2/p%Q_Nose &
         + 3*p%N*p%temperature_eV*log(c%s_Nose) &
         - c%H0
    e%H_Nose_Poincare = e%H_Nose_Poincare * c%s_Nose
  end subroutine Nose_Poincare_Hamiltonian

  subroutine inhomogeneous_strain_energy(p,c,e)
    use Param_module
    use Coord_module
    implicit none
    !--- arguments -------------------------------------
    type(Param_type),  intent(in)    :: p
    type(Coord_type),  intent(in)    :: c
    type(Energy_type), intent(inout) :: e
    !--- local -----------------------------------------
    real*8  :: tmp1,tmp2,tmp3,tmpS
    integer :: alpha,beta, iy,iz
    !--- END of variable definitions -------------------
    tmpS = 0.0d0
!$omp parallel do private(tmp1,tmp2,tmp3) reduction (+:tmpS)
    do iz = 0, p%Lz-1
       do iy = 0, p%Ly-1
          do alpha = 1,3
             do beta = 1,3
                tmp1 =      dble( conjg(c%acouK(alpha, 0,         iy,iz)) * c%inhomo_K(alpha,beta, 0,         iy,iz) * c%acouK(beta, 0,         iy,iz)) / 2
                tmp2 = sum( dble( conjg(c%acouK(alpha, 1:p%Lx/2-1,iy,iz)) * c%inhomo_K(alpha,beta, 1:p%Lx/2-1,iy,iz) * c%acouK(beta, 1:p%Lx/2-1,iy,iz)) )
                tmp3 =      dble( conjg(c%acouK(alpha,   p%Lx/2,  iy,iz)) * c%inhomo_K(alpha,beta,   p%Lx/2,  iy,iz) * c%acouK(beta,   p%Lx/2,  iy,iz)) / 2
                tmpS = tmpS + tmp1 + tmp2 + tmp3
             end do
          end do
       end do
    end do
!$omp end parallel do
    e%inho_strain = tmpS * p%Ninv    ! Do NOT divide it by 2 here. It has been already devided.
  end subroutine inhomogeneous_strain_energy

  subroutine inhomogeneous_coupling_energy(p,c,e)
    use Param_module
    use Coord_module
    implicit none
    !--- arguments -------------------------------------
    type(Param_type),  intent(in)    :: p
    type(Coord_type),  intent(in)    :: c
    type(Energy_type), intent(inout) :: e
    !--- local -----------------------------------------
    real*8  :: tmp1,tmp2,tmp3,tmpS
    integer :: i, alpha, iy,iz
    !--- END of variable definitions -------------------
    tmpS = 0.0d0
!$omp parallel do private(tmp1,tmp2,tmp3) reduction (+:tmpS)
    do iz = 0, p%Lz-1
       do iy = 0, p%Ly-1
          do i = 1,6
             do alpha = 1,3
                tmp1 =      dble( conjg(c%acouK(alpha, 0,         iy,iz)) * c%inhomo_coup2_K(alpha,i, 0,         iy,iz) * c%didiK(i, 0,         iy,iz) ) / 2
                tmp2 = sum( dble( conjg(c%acouK(alpha, 1:p%Lx/2-1,iy,iz)) * c%inhomo_coup2_K(alpha,i, 1:p%Lx/2-1,iy,iz) * c%didiK(i, 1:p%Lx/2-1,iy,iz) ) )
                tmp3 =      dble( conjg(c%acouK(alpha,   p%Lx/2,  iy,iz)) * c%inhomo_coup2_K(alpha,i,   p%Lx/2,  iy,iz) * c%didiK(i,   p%Lx/2,  iy,iz) ) / 2
                tmpS = tmpS + tmp1 + tmp2 + tmp3
             end do
          end do
       end do
    end do
!$omp end parallel do
    e%inho_coupling = tmpS * 2 * p%Ninv
  end subroutine inhomogeneous_coupling_energy

  subroutine inhomogeneous_modulation_energy(p,c,e)
    use Param_module
    use Coord_module
    implicit none
    !--- arguments -------------------------------------
    type(Param_type),  intent(in)    :: p
    type(Coord_type),  intent(in)    :: c
    type(Energy_type), intent(inout) :: e
    !--- local -----------------------------------------
    real*8  :: tmp1,tmp2,tmp3,tmpS
    integer :: alpha, iy,iz
    !--- END of variable definitions -------------------
    if (p%modulation_constant.eq.0.0d0) then
       e%inho_modulation = 0.0d0
       return
    end if
    tmpS = 0.0d0
!$omp parallel do private(tmp1,tmp2,tmp3) reduction (+:tmpS)
    do iz = 0, p%Lz-1
       do iy = 0, p%Ly-1
             do alpha = 1,3
                tmp1 =      dble( conjg(c%acouK(alpha, 0,         iy,iz)) * c%c_k_modulation_k(alpha, 0,         iy,iz) ) / 2
                tmp2 = sum( dble( conjg(c%acouK(alpha, 1:p%Lx/2-1,iy,iz)) * c%c_k_modulation_k(alpha, 1:p%Lx/2-1,iy,iz) ) )
                tmp3 =      dble( conjg(c%acouK(alpha,   p%Lx/2,  iy,iz)) * c%c_k_modulation_k(alpha,   p%Lx/2,  iy,iz) ) / 2
                tmpS = tmpS + tmp1 + tmp2 + tmp3
             end do
       end do
    end do
!$omp end parallel do
    e%inho_modulation = tmpS * 2 * p%Ninv
  end subroutine inhomogeneous_modulation_energy
end module Energy_module
