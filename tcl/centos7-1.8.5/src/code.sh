result=$(which tclsh)
if [ "$?" -ne 0 ]; then
   result=$(yum install -y tcl tcllib expect dos2unix)
   if [ $? -ne 0 ]; then
      exit 1
   fi
fi

echo "@@success@@"
exit 0
