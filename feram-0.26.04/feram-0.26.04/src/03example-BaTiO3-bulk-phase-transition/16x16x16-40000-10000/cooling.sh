#!/bin/sh
# cooling.sh
# Time-stamp: <2012-11-29 13:17:43 t-nissie>
# Author: Takeshi NISHIMATSU
##

# 删除cooling.avg文件
rm -f cooling.avg

#初始温度为350k
temperature_start=350
#目标温度为170k
temperature_goal=170
#迭代步长为-5k
temperature_step=-5
#
n_thermalize=40000
#
n_average=10000
# expr:可以实现数值运算、数值或字符串比较、字符串匹配、字符串提取、字符串长度计算等功能。本处应该是用做数值运算
n_coord_freq=`expr $n_thermalize + $n_average`

#做迭代操作，每次更新温度，生成该温度下的相关配置文件，并计算，生成该温度下的结果文件
i=0
temperature=$temperature_start
# perl -e：在命令行中使用 -e 选项：输入语句执行代码，执行成功则为1，跳出循环
while [ `perl -e "print $temperature >= $temperature_goal || 0"` = "1" ] ; do
    i=`expr $i + 1`
	#生成文件的名称
    filename=cooling`printf '%.3d' $i`-"$temperature"K
	#将相关参数写入文件
    cat > $filename <<-EOF
	#--- Method, Temperature, and mass ---------------
	method = 'md'
	GPa = -5.0
	kelvin = $temperature
	mass_amu = 39.0
	Q_Nose = 0.1
	
	#--- System geometry -----------------------------
	bulk_or_film = 'bulk'
	L = 16 16 16
	a0 =  3.94         latice constant a0 [Angstrom]
	#--- Time step -----------------------------------
	dt = 0.002 [pico second]
	n_thermalize = $n_thermalize
	n_average    = $n_average
	n_coord_freq = $n_coord_freq
	distribution_directory = 'never'
	
	#--- On-site (Polynomial of order 4) -------------
	P_kappa2 =    5.502  [eV/Angstrom^2] # P_4(u) = kappa2*u^2 + alpha*u^4
	P_alpha  =  110.4    [eV/Angstrom^4] #  + gamma*(u_y*u_z+u_z*u_x+u_x*u_y),
	P_gamma  = -163.1    [eV/Angstrom^4] # where u^2 = u_x^2 + u_y^2 + u_z^2
	
	#--- Inter-site ----------------------------------
	j = -2.648 3.894 0.898 -0.789 0.562 0.358 0.179    j(i) [eV/Angstrom^2]
	
	#--- Elastic Constants ---------------------------
	B11 = 126.
	B12 =  44.9
	B44 =  50.3  [eV]
	
	#--- Elastic Coupling ----------------------------
	B1xx = -211.   [eV/Angstrom^2]
	B1yy =  -19.3  [eV/Angstrom^2]
	B4yz =   -7.75 [eV/Angstrom^2]
	
	#--- Dipole --------------------------------------
	init_dipo_avg = 0.0   0.0   0.0    [Angstrom]  # Average   of initial dipole displacements
	init_dipo_dev = 0.03  0.03  0.03   [Angstrom]  # Deviation of initial dipole displacements
	Z_star        = 9.956
	epsilon_inf   = 5.24
EOF
    #echo 1 > FILES
    #echo $filename >> FILES
	#使用上一次计算的结果当做当前计算的初值
    if [ -r "$prev_coord" ]; then
        ln -sf "$prev_coord" $filename.restart
    fi
	#计算入口：可以选择是feram或feram_mpi
    ../../feram $filename
	#将当前计算完成的结果赋给上一次计算的结果
    prev_coord=$filename.`printf '%.10d' $n_coord_freq`.coord
    cat $filename.avg >> cooling.avg
    temperature=`perl -e "print $temperature + $temperature_step"`
done
