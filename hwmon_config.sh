#/bin/sh

# SPDX-FileCopyrightText: Robert Ryszard Paciorek <rrp@opcode.eu.org>
# SPDX-License-Identifier: MIT

p=`ls -d /sys/bus/pci/drivers/k10temp/0*/hwmon/hwmon*`
for f in $p/*_label; do
	case `cat $f` in
		Tctl)  echo "cpu.temp.ctl" $p/`basename $f _label`_input ;;
		Tccd1) echo "cpu.temp.ccd1" $p/`basename $f _label`_input ;;
		Tccd2) echo "cpu.temp.ccd2" $p/`basename $f _label`_input ;;
	esac
done

p=`ls -d /sys/bus/pci/devices/0000:73:00.0/hwmon/hwmon*`
for f in $p/*_label; do
	case `cat $f` in
		edge) echo "cpu.temp.gpu_edge" $p/`basename $f _label`_input  ;;
	esac
done

p=`ls -d /sys/bus/pci/devices/0000:03:00.0/hwmon/hwmon*`
for f in $p/*_label; do
	case `cat $f` in
		PPT)  echo "gpu.power.ppt" $p/`basename $f _label`_average ;;
		edge) echo "gpu.temp.edge" $p/`basename $f _label`_input  ;;
		mem) echo "gpu.temp.mem" $p/`basename $f _label`_input ;;
		junction) echo "gpu.temp.junction" $p/`basename $f _label`_input ;;
	esac
done

p=/sys/bus/i2c/devices/1-005*/hwmon/hwmon*
i=0; for f in $p; do
	i=$(( $i+1 )); echo "ram.temp.c$i" $f/temp1_input
done

p=/sys/bus/mdio_bus/devices/*/hwmon/hwmon*
i=0; for f in $p; do
	i=$(( $i+1 )); echo "mdio.temp.c$i" $f/temp1_input
done

p=/sys/block/sd*/device/hwmon/hwmon*/temp1_input
for f in $p; do
	d=`echo $p | cut -f4 -d/`
	echo "disks.temp.$d" $f
done

p=`ls -d /sys/bus/platform/devices/nct*/hwmon/hwmon*`
for f in $p/*_label; do
	case `cat $f` in
		SYSTIN)  echo "mb.temp.sysin" $p/`basename $f _label`_input ;;
		CPUTIN) echo "mb.temp.cpuin" $p/`basename $f _label`_input ;;
		AUXTIN1) echo "mb.temp.auxtin1" $p/`basename $f _label`_input ;;
		AUXTIN2) echo "mb.temp.auxtin2" $p/`basename $f _label`_input ;;
		AUXTIN3) echo "mb.temp.auxtin3" $p/`basename $f _label`_input ;;
		AUXTIN4) echo "mb.temp.auxtin4" $p/`basename $f _label`_input ;;
		AUXTIN5) echo "mb.temp.auxtin5" $p/`basename $f _label`_input ;;
		TSI0_TEMP) echo "mb.temp.tsi0" $p/`basename $f _label`_input ;;
	esac
done
echo "mb.base_dir" $p
