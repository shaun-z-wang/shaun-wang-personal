# gohan never puts its node runtime on PATH, and the asdf shims fail without ASDF_DATA_DIR
# plus a .tool-versions pin matching an installed version
_node_runtime="/home/bento/.config/gohan/runtimes/node/24.22.1/bin"
[ -d "$_node_runtime" ] && export PATH="$_node_runtime:$PATH"
unset _node_runtime
