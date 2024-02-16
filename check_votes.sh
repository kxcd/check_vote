#!/bin/bash
#set -x
set -e

# An array of protx hashes.
MASTERNODES=(0062e548ac39d518de7b74b9ea92cf6735a8699a3d70896e533dbb5167aedd0b 0092aa49ee56297a47a5ee6dccca746b58a69f1bf9a24e3e28d9c1ea9bae41ea 00a60e606dd7724391d9f8ee9245b03144921149d6c294439ee81ccdd1de9d2d 00a6aa2d8bc371d4577c887a5c68003b75dba238eebc9c6d76941b1e7b7a4304 fef139ff6fc509529dad0540a48d5b305dc3eb319c7de3afb3ff63f52d838d95 ff00b58e4b281f41d6d87df335ab8e632177c3c2ec57c6e4e0d7f248e0bb9f51 ff09ea3a7ef93a0bf5179cec8eee1271a15afc702902b5d6f5a38331e206d3b0 ff93208c66329768323a47711f7e8c211c8b42dd38b8a2dc36118d1d70fe673e ff93af84ac3f7cd70dc522696e9d012662e00fff403ff78f122e6dbd7a6a4b54 ffa4a74c58aa0002696df1a7d2562b5a36f5116581a0df1a91500a9664985f52 ffa516477af8d6a3cea068a625401415934585f71e6fad72c880ed157da95f92 ffaaf68b98d79e28fd26f9404696385f64d3576af39507adfc295e8037993787)


txtred='\e[0;31m' # Red
txtgrn='\e[0;32m' # Green
txtylw='\e[0;33m' # Yellow
txtblu='\e[0;34m' # Blue
txtpur='\e[0;35m' # Purple
txtcyn='\e[0;36m' # Cyan
txtwht='\e[0;37m' # White
bldred='\e[1;31m' # Red
bldgrn='\e[1;32m' # Green
bldylw='\e[1;33m' # Yellow
bldblu='\e[1;34m' # Blue
bldpur='\e[1;35m' # Purple
bldcyn='\e[1;36m' # Cyan
bldwht='\e[1;37m' # White

txtrst='\e[0m'    # Text Reset

[[ $1 == "-debug" ]]&&debug=yes

COLLATERALS=()
TYPES=()

# Create the array of collaterals via the protx lookup.
for (( i=0; i < "${#MASTERNODES[*]}"; i++ ));do
	protx_info=$(dash-cli protx info "${MASTERNODES[$i]}")
	collateral=$(jq -r '"\(.collateralHash)-\(.collateralIndex)"' <<< "$protx_info")
	COLLATERALS[$i]=$collateral
	TYPES[$i]=$(jq -r ".type"<<<"$protx_info")
done

#echo "${COLLATERALS[@]}"


# Find all the proposal names and hashes.
declare -A PROPOSALS

gobject=$(dash-cli gobject list all proposals)
for hash in $(jq -r '.[].Hash' <<<"$gobject");do
	dataHex=$(jq -r ".\"$hash\".DataHex"<<<"$gobject")
	dataString=$(dash-cli gobject deserialize "$dataHex")
	objectType=$(jq -r '.type'<<<"$dataString")
	((objectType==2))&&continue
	name=$(jq -r '.name'<<<"$dataString")
	PROPOSALS[$hash]="$name"
done

#for key in "${!PROPOSALS[@]}"; do echo "$key --- ${PROPOSALS[$key]}"; done

# Determine longest proposal name length
prop_name_length=0
for prop_hash in "${!PROPOSALS[@]}";do
	length=${#PROPOSALS[$prop_hash]}
	((length>prop_name_length))&&prop_name_length=$length
done
#echo "Length: $prop_name_length"


[[ -n $debug ]]&&((prop_name_length+=64))

# Print the header.
for((i=0;i<prop_name_length;i++));do
	header+=" "
done
echo -e "$header  M A S T E R N O D E S\n"
for((i=0;i<${#MASTERNODES[@]};i++));do
	[[ "${TYPES[$i]}" == "Evo" ]]&&header+="  ${bldwht}$((i+1))${txtrst}"||header+="  $((i+1))"
done
echo -e "$header"
header_length=$(echo -e "$header" |sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g"|awk '{print length}')
for((i=0;i<header_length;i++));do
	spacer+="-"
done
echo "$spacer"

# How we voted.  I am sorting the proposals on value first.
for prop_hash in $(for key in "${!PROPOSALS[@]}"; do echo "$key ${PROPOSALS[$key]}"; done|sort -k2|awk '{print $1}');do
	row="${PROPOSALS[$prop_hash]}"
	[[ -n $debug ]]&&row="$prop_hash $row"
	while((${#row}<prop_name_length));do
		row+=" "
	done

	count=0
	for collateral in "${COLLATERALS[@]}";do
		# Can't use ((count++)) because it returns false to the shell.
		let count=count+1
		#echo "prop_hash: $prop_hash collateral: $collateral split: $(sed 's/-/ /' <<<"$collateral")"
		vote=$(dash-cli gobject getcurrentvotes "$prop_hash" ${collateral//-/ }|awk -F ':' '/funding/{print substr($4,1,1)}')
		((${#vote}==0))&&vote=" "
		case $vote in
			y)
				vote="${bldgrn}${vote}${txtrst}"
				;;
			n)
				vote="${bldred}${vote}${txtrst}"
				;;
			a)
				vote="${bldblu}${vote}${txtrst}"
				;;
			*)
				;;
		esac
		((count>10))&&row+=" "
		row+="  $vote"
	done
	echo -e "$row"
done

# Print the key.
echo -e "\nLegend\n"
padding=" "
for((i=0;i<${#MASTERNODES[@]};i++));do
	((i==9))&&padding=
	echo "$((i+1))${padding} - ${MASTERNODES[$i]} ${TYPES[$i]}"
done


