echo "Do you wish to install this program?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) echo "install"; break;;
        No ) exit;;
    esac
done
