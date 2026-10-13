_sel_extend() { (( REGION_ACTIVE )) || zle set-mark-command; zle ".$1"; }
_sel_drop()   { REGION_ACTIVE=0; zle "$1"; }
_sel_pairs=(
  sel-char-left  backward-char      '^[[1;2D'
  sel-char-right forward-char       '^[[1;2C'
  sel-word-left  backward-word      '^[[1;4D'
  sel-word-right forward-word       '^[[1;4C'
  sel-line-left  beginning-of-line  '^[[1;2H'
  sel-line-right end-of-line        '^[[1;2F'
)
for _n _w _k in $_sel_pairs; do
  eval "$_n() { _sel_extend $_w; }"
  zle -N $_n
  bindkey "$_k" $_n
done
for _w in backward-char forward-char backward-word forward-word beginning-of-line end-of-line; do
  eval "_mv-$_w() { _sel_drop .$_w; }"
  zle -N $_w _mv-$_w
done
_sel_insert() { (( REGION_ACTIVE )) && zle kill-region; zle .self-insert; }
_sel_paste()  { (( REGION_ACTIVE )) && zle kill-region; zle .bracketed-paste; }
_sel_bs()     { if (( REGION_ACTIVE )); then zle kill-region; else zle .backward-delete-char; fi; }
_sel_del()    { if (( REGION_ACTIVE )); then zle kill-region; else zle .delete-char; fi; }
zle -N self-insert _sel_insert
zle -N bracketed-paste _sel_paste
zle -N backward-delete-char _sel_bs
zle -N delete-char _sel_del
unset _sel_pairs _n _w _k
