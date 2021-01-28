#!/bin/bash
#set -x
set -e

# An array of protx hashes.
MASTERNODES=(bc5ab1d9d0ef562563194b1eb594c248919d014b106b0d3759fc3fd577da2054 7166801342a2f09358ae4d3720f912c439605db9f58af362e9eccd44e8509fbb e8ce80ea903a5f4af70dfed189fbcf6926374743202c4cedafe58c21eafdc51b a569acf816ff49a72c18a62bdcc59bb95ed962c9c6ceae2fb4006e30d1946700 65650b10d273b74db238649477bc24222b4171cc1bbb8e0bd414d0eedee76f4f f134927ab6aeed105d1ac93ca3b9d2f197831abad91540e125aec03e8ae33437 7afd763df1b77ac1e9fa2a43d7387142fba5bb10e89462b16c9d1d14347d4c4c f1916d329797bb25ad4062e193473b9b48c344c10b48dc1bd5ee5ebb6b499a0a)


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


COLLATERALS=()

# Create the array of collaterals via the protx lookup.
for (( i=0; i < "${#MASTERNODES[*]}"; i++ ));do
	protx_info=$(dash-cli protx info "${MASTERNODES[$i]}")
	collateral=$(jq -r '"\(.collateralHash)-\(.collateralIndex)"' <<< "$protx_info")
	COLLATERALS[$i]=$collateral
done

#echo "${COLLATERALS[@]}"


# Find all the proposal names and hashes.
declare -A PROPOSALS

gobject=$(dash-cli gobject list)
for hash in $(echo "$gobject"|grep -i -o '"[1234567890abcdef]*": {'|grep -i -o '[1234567890abcdef]*');do
	proposalHash=$(jq -r ".\"$hash\".Hash"<<<"$gobject")
	dataHex=$(jq -r ".\"$hash\".DataHex"<<<"$gobject")
	dataString=$(dash-cli gobject deserialize "$dataHex")
	objectType=$(jq -r '.type'<<<"$dataString")
	if((objectType==2));then break;fi
	name=$(jq -r '.name'<<<"$dataString")
	PROPOSALS[$proposalHash]="$name"
done

#for key in "${!PROPOSALS[@]}"; do echo "$key --- ${PROPOSALS[$key]}"; done

# Determine longest proposal name length
prop_name_length=0
for prop_hash in "${!PROPOSALS[@]}";do
	length=${#PROPOSALS[$prop_hash]}
	((length>prop_name_length))&&prop_name_length=$length
done
#echo "Length: $prop_name_length"

# Print the header.
for((i=0;i<prop_name_length;i++));do
	header+=" "
done
echo -e "$header  M A S T E R N O D E S\n"
for((i=0;i<${#MASTERNODES[@]};i++));do
	header+="  $((i+1))"
done
echo "$header"
for((i=0;i<${#header};i++));do
	spacer+="-"
done
echo "$spacer"

# How we voted.  I am sorting the proposals on value first.
for prop_hash in $(for key in "${!PROPOSALS[@]}"; do echo "$key ${PROPOSALS[$key]}"; done|sort -k2|awk '{print $1}');do
	row="${PROPOSALS[$prop_hash]}"
	while((${#row}<prop_name_length));do
		row+=" "
	done

	for collateral in "${COLLATERALS[@]}";do
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
		row+="  $vote"
	done
	echo -e "$row"
done

# Print the key.
echo -e "\nLegend\n"
for((i=0;i<${#MASTERNODES[@]};i++));do
    echo "$((i+1)) - ${MASTERNODES[$i]}"
done
