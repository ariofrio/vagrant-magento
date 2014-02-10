# Setup

 1. Install the latest [VirtualBox](https://www.virtualbox.org).

 2. Install the latest [Vagrant](http://vagrantup.com/).

 3. To speed up the time it takes to create and destroy a VM, run:

        vagrant plugin install vagrant-cachier

 4. Clone this repository:

        git clone https://github.com/ariofrio/vagrant-magento.git

 5. Provision the virtual machine (First time users see NOTE below). Don't forget to replace `MYNAME` with the subdomain you want.

    Run this on Linux or Mac OS X:

        cd vagrant-magento
        SUBDOMAIN=MYNAME vagrant up

    If you are running `cmd` on Windows, run the following instead:

        cd vagrant-magento
        set SUBDOMAIN=MYNAME
        vagrant up
        set SUBDOMAIN=

    Finally, on PowerShell, run this:

        cd vagrant-magento
        cmd /c "set SUBDOMAIN=MYNAME && vagrant up"
	
	NOTE:: This will take 15-20 minutes the first time. The default Box 'precise64' will be downloaded from the following URL: "http://files.vagrantup.com/precise64.box". Don't panic! This is supposed to happen :]
# Usage

## Magento

Go to <http://MYNAME.ngrok.com/magento/> for the frontend and <http://MYNAME.ngrok.com/magento/admin/> for the backend. Anyone can access this ngrok subdomain from any device to reach your virtual machine.

The username is `admin` and the password is `password123`.

## phpMyAdmin

Go to <http://MYNAME.ngrok.com/phpmyadmin/>. The username is `root` and the password is `root` also.

## Changing the subdomain

Open `vagrant-magento/config/ngrok_subdomain.txt` in a text editor and change the last line to the subdomain name you want. Then run:

    cd vagrant-magento
    vagrant reload

For example, if you change the last line to `nick`, you will be able to access Magento and phpMyAdmin from <http://nick.ngrok.com>.

## Starting over

To reset the Magento database, run the following command. This time, it should only take about 3 minutes.

    vagrant destroy && vagrant up

To view all the file changes you've made in the Magento directory, run:

    cd vagrant-magento/magento
    git status

To reset the Magento directory structure, run:

    cd vagrant-magento/magento
    git reset --hard   # reset changes to existing files
    git clean -n -d    # list new files that will be removed by the next command
    git clean -f -d    # remove new files

## Halting the virtual machine

To free up some memory on your system while you are not using it, you can halt the virtual machine (and still keep your database) by running:

    vagrant halt

Bring it back up with:

    vagrant up
