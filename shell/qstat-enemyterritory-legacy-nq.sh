#!/bin/bash
# this works with the NQ (No Quarter) mod 1.2.9b6 in conjunction
# with ET:Legacy 2.74
# generate a simple HTML table with quakestat (qstat) data
# this will also now parse logs and print recent players over past 24hrs
# requires quakestat for HTML, convert and html2ps for image conversion
# I use the following .html2psrc
#BODY {
#     font-size: 16pt;
#     }

gameserver="example.com"

# variables for qstat generation
ETHTML="/tmp/nq.html"
ETFULL="/tmp/nqfull.txt"
ETTXT="/tmp/nq.txt"
ETPS="/tmp/nq.ps"
ETHOMEHTML="/home/`whoami`/public_html/nq.html"
ETHOMEIMG="/home/`whoami`/public_html/html/nq.png"

# variables for recent players
DATE=`date +%Y%m%d`
ETLOG="/home/`whoami`/ETL32/CURRENT_LOG"
ETPLAYERLOG="/tmp/nqplayers.txt"
ETPLAYERSTRIP="/tmp/nqplayerstrip.txt"
ETPLAYERHTML="/tmp/nqplayerstrip.html"
ETPLAYERSHORT="/tmp/nqplayerstripshort.txt"
ETPLAYERSHORTRAW="/tmp/utplayerstripshortraw.txt"

tmpfiles=($ETHTML $ETFULL $ETTXT $ETPS $ETPLAYERLOG $ETPLAYERSTRIP $ETPLAYERHTML \
		$ETPLAYERSHORT $ETPLAYERSHORTRAW)

cleanup_files() {
for i in ${tmpfiles[*]}; do
        if [ -e $i ]; then
                rm -f $i
        fi
done
}

qstat_generate() {
	# generate generic status
        /usr/bin/quakestat -woets $gameserver -P -raw "|" > $ETTXT
	srv=`cat $ETTXT | awk -F "|" 'NR==1{print $2}'`
	pc=`cat $ETTXT | awk -F "|" 'NR==1{print $6}'`
	pclimit=`cat $ETTXT | awk -F "|" 'NR==1{print $5}'`
	gmap=`cat $ETTXT | awk -F "|" 'NR==1{print $4}'`
	gping=`cat $ETTXT | awk -F "|" 'NR==1{print $7}'`
	srvtype=`cat $ETTXT | awk -F "|" 'NR==1{print $3}'`

        # generate generic CSS template for status
        cat > $ETHTML <<EOF
<style type="text/css">
.tg  {border-collapse:collapse;border-spacing:0;border-color:#ccc;}
.tg td{font-family:Arial, sans-serif;font-size:14px;padding:10px 5px;border-style:solid;border-width:0px;overflow:hidden;word-break:normal;border-color:#ccc;color:#333;background-color:#fff;}
.tg th{font-family:Arial, sans-serif;font-size:14px;font-weight:normal;padding:10px 5px;border-style:solid;border-width:0px;overflow:hidden;word-break:normal;border-color:#ccc;color:#333;background-color:#f0f0f0;}
.tg .tg-edkc{font-size:28px;vertical-align:top}
.tg .tg-24i8{font-size:24px;vertical-align:top}
</style>
<table class="tg">
  <tr>
    <th class="tg-edkc">ADDRESS<br></th>
    <th class="tg-edkc">PLAYERS</th>
    <th class="tg-edkc">MAP</th>
    <th class="tg-edkc">PING<br></th>
    <th class="tg-edkc">SERVER NAME</th>
  </tr>
  <tr>
    <td class="tg-24i8">$srv</td>
    <td class="tg-24i8">$pc of $pclimit</td>
    <td class="tg-24i8">$gmap</td>
    <td class="tg-24i8">$gping</td>
    <td class="tg-24i8">$srvtype</td>
  </tr>
</table>
EOF

    # generate generic CSS for table title
    cat >> $ETHTML << EOF
<table class="tg">
  <tr>
    <th class="tg-edkc">Current Players<br></th>
</tr>
<br>
EOF
    
    # generate player info and frags and append
    /usr/bin/quakestat -woets $gameserver -P | tail -n+3 > $ETFULL 
    # replace 'frags' with 'experience' since that's what qstat reports
    sed -i -e 's/frags/experience/' /tmp/etfull.txt
    cat $ETFULL | awk 'BEGIN{print "<table>"} {print "<tr>";for(i=1;i<=NF;i++)print \
		"<td>" $i"</td>";print "</tr>"} END{print "</table>"}' >> $ETHTML 
}

daily_players() {
        # get list of daily players in form of "G_xpsave_add: saved xp for $player"
        cat $ETLOG | grep "saved xp" | egrep -v '\[BOT\]' | sort | uniq > $ETPLAYERLOG
        # strip out only the players names, this will also pick up spaces
        cat $ETPLAYERLOG | awk '{$1=$2=$3=$4=""; print $0}' > $ETPLAYERSHORTRAW
        # strip out ANSII codes used in ET:L logging
	perl -e 'use Term::ANSIColor; print color "white"; print "ABC\n"; print color "reset";' | \
        perl -pe 's/\x1b\[[0-9;]*m//g' $ETPLAYERSHORTRAW > $ETPLAYERSHORT

}

generate_playerhtml() {
        # generate generic CSS for table title
        cat > $ETPLAYERHTML << EOF
<table class="tg">
  <tr>
    <th class="tg-edkc">Recent Players<br></th>
</tr>
<br>
EOF
        # generate nice HTML of recent players
        cat $ETPLAYERSHORT | awk 'BEGIN{print "<table>"} {print "<tr>";for(i=1;i<=NF;i++)print \
                "<td>" $i"</td>";print "</tr>"} END{print "</table>"}' >> $ETPLAYERHTML
}

html_convert() {
    # merge the two HTML files
    cat $ETPLAYERHTML >> $ETHTML  
    # HTML copy  
    cp $ETHTML $ETHOMEHTML
    # create image of HTML page
    /usr/bin/html2ps -F $ETHTML > $ETPS
    convert $ETPS $ETHOMEIMG
}

cleanup_files
qstat_generate
daily_players
generate_playerhtml
html_convert
