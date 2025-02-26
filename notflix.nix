{ pkgs, ... }:
  let
    c = x: "${pkgs.coreutils}/bin/${x}";
    mkdir = "${c "mkdir"}";
    echo "${c "echo"}";
    tr = "${c "tr"}";
    mv = "${c "mv"}";
    cut = "${c "cut"}";
    head = "${c "head"}";
    tail = "${c "tail"}";
    dmenu = "${pkgs.dmenu}/bin/dmenu";
    sed = "${pkgs.gnused}/bin/sed";
    curl = "${pkgs.curl}/bin/curl";
    grep = "${pkgs.gnugrep}/bin/grep";
    awk = "${pkgs.gawk}/bin/awk";
    webtorrent = "${pkgs.webtorrent_desktop}/bin/webtorrent}";
  in pkgs.writeShellScriptBin "notflix" ''
    #!/bin/sh
    
    # Dependencies - webtorrent, mpv
    
    ${mkdir} -p $HOME/.cache/notflix
    
    menu="${dmenu} -i -l 25"
    baseurl="https://1337x.wtf"
    cachedir="$HOME/.cache/notflix"
    
    if [ -z $1 ]; then
      query=$(${dmenu} -p "Search Torrent: " <&-)
    else
      query=$1
    fi
    
    query="$(${echo} $query | ${sed} 's/ /+/g')"
    
    #${curl} -s https://1337x.to/category-search/$query/Movies/1/ > $cachedir/tmp.html
    ${curl} -s $baseurl/search/$query/1/ > $cachedir/tmp.html
    
    # Get Titles
    ${grep} -o '<a href="/torrent/.*</a>' $cachedir/tmp.html |
      ${sed} 's/<[^>]*>//g' > $cachedir/titles.bw
    
    result_count=$(wc -l $cachedir/titles.bw | ${awk} '{print $1}')
    if [ "$result_count" -lt 1 ]; then
      ${echo} "😔 No Result found. Try again 🔴" -i "NONE"
      exit 0
    fi
    
    # Seeders and Leechers
    ${grep} -o '<td class="coll-2 seeds.*</td>\|<td class="coll-3 leeches.*</td>' $cachedir/tmp.html |
      ${sed} 's/<[^>]*>//g' | ${sed} 'N;s/\n/ /' > $cachedir/seedleech.bw
    
    # Size
    ${grep} -o '<td class="coll-4 size.*</td>' $cachedir/tmp.html |
      ${sed} 's/<span class="seeds">.*<\/span>//g' |
      ${sed} -e 's/<[^>]*>//g' > $cachedir/size.bw
    
    # Links
    ${grep} -E '/torrent/' $cachedir/tmp.html |
      ${sed} -E 's#.*(/torrent/.*)/">.*/#\1#' |
      ${sed} 's/td>//g' > $cachedir/links.bw
    
    # Clearning up some data to display
    ${sed} 's/\./ /g; s/\-/ /g' $cachedir/titles.bw |
      ${sed} 's/[^A-Za-z0-9 ]//g' | ${tr} -s " " > $cachedir/tmp && ${mv} $cachedir/tmp $cachedir/titles.bw
    
    ${awk} '{print NR " - ["$0"]"}' $cachedir/size.bw > $cachedir/tmp && ${mv} $cachedir/tmp $cachedir/size.bw
    ${awk} '{print "[S:"$1 ", L:"$2"]" }' $cachedir/seedleech.bw > $cachedir/tmp && ${mv} $cachedir/tmp $cachedir/seedleech.bw
    
    # Getting the line number
    LINE=$(paste -d\   $cachedir/size.bw $cachedir/seedleech.bw $cachedir/titles.bw |
      $menu |
      ${cut} -d\- -f1 |
      ${awk} '{$1=$1; print}')
    
    if [ -z "$LINE" ]; then
      ${echo} "😔 No Result selected. Exiting... 🔴" -i "NONE"
      exit 0
    fi
    ${echo} "🔍 Searching Magnet seeds 🧲" -i "NONE"
    url=$(${head} -n $LINE $cachedir/links.bw | ${tail} -n +$LINE)
    fullURL="$baseurl$url/"
    
    # Requesting page for magnet link
    ${curl} -s $fullURL > $cachedir/tmp.html
    magnet=$(${grep} -Po "magnet:\?xt=urn:btih:[a-zA-Z0-9]*" $cachedir/tmp.html | ${head} -n 1) 
    
    ${webtorrent} "$magnet" --mpv
    
    # Simple notification
    ${echo} "🎥 Enjoy Watching ☺️ " -i "NONE"
  '';
}
