#!/bin/sh
# usage: set.sh S1PROP S1DRY U1PROP U1DRY U1THR U2PROP U2DRY FINSPAN MINF MAXF
S1P=$1 S1D=$2 U1P=$3 U1D=$4 U1T=$5 U2P=$6 U2D=$7 SPAN=$8 MINF=$9 MAXF=${10} perl -0pi -e '
my ($head,$juno)=split(/(?="id": "juno_class")/,$_,2);
$juno =~ s/"propellant_mass_kg": 24\d*,\n(\s*)"dry_mass_kg": \d+/"propellant_mass_kg": $ENV{S1P},\n$1"dry_mass_kg": $ENV{S1D}/;
$juno =~ s/"propellant_mass_kg": \d+,\n(\s*)"dry_mass_kg": \d+,\n(\s*)"propellant_density_kg_m3": 1700,\n(\s*)"ullage_factor": 1.05\n(\s*)\},\n(\s*)"engine": \{\n(\s*)"count": 1,\n(\s*)"section_length_m": 0.6/"propellant_mass_kg": $ENV{U1P},\n$1"dry_mass_kg": $ENV{U1D},\n$2"propellant_density_kg_m3": 1700,\n$3"ullage_factor": 1.05\n$4},\n$5"engine": {\n$6"count": 1,\n$7"section_length_m": 0.6/;
$juno =~ s/"thrust_vac_N": 6\d*000/"thrust_vac_N": $ENV{U1T}/;
$juno =~ s/"propellant_mass_kg": \d+,\n(\s*)"dry_mass_kg": \d+,\n(\s*)"propellant_density_kg_m3": 1700,\n(\s*)"ullage_factor": 1.05\n(\s*)\},\n(\s*)"engine": \{\n(\s*)"count": 1,\n(\s*)"section_length_m": 0.4/"propellant_mass_kg": $ENV{U2P},\n$1"dry_mass_kg": $ENV{U2D},\n$2"propellant_density_kg_m3": 1700,\n$3"ullage_factor": 1.05\n$4},\n$5"engine": {\n$6"count": 1,\n$7"section_length_m": 0.4/;
$juno =~ s/"span_m": [\d.]+/"span_m": $ENV{SPAN}/;
$juno =~ s/"min_factor": [\d.]+,\n(\s*)"max_factor": [\d.]+/"min_factor": $ENV{MINF},\n$1"max_factor": $ENV{MAXF}/;
$_ = $head.$juno;' data/reference_rockets.json
