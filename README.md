Varnish Configuration for WordPress
===================================

Hi there, I currently use Varnish for my WordPress blog (which is hosted in a Linode 512 machine).

This config is specially prepared for keeping things as fast as possible and secure. There are a lot of other configs around here, so take a look to the others if my config doesn't convince you!

This is my first release so if I made a mistake please mark an issue or feel free to fork and contribute!

*NOTES*: Currently I'm working on it (so don't use it right now! Even this
documentation will change).

Features
--------

- WordPress Admin and Login are blocked by default (You need to enable a SOCKS proxy in order to access it). See: https://calomel.org/firefox_ssh_proxy.html
- Health checks to your server in order to serve content whatever happens to your backend.
- Source code heavily commented to understand what's going on!

Stack
-----

- WordPress (obviously)
- W3 Total Cache (for purging your Varnish cache everytime you publish something)
- Nginx
- Varnish 3.0

Installation Instructions
-------------------------

1.-

$ sudo aptitude install libvarnishapi-dev varnish-dbg build-essential automake libtool autoconf libpcre3-dev pkg-config python-docutils

2.- 

$ sudo apt-get source varnish
$ cd varnish\*
$ ./configure
$ make

3.-

$ git clone git://github.com/varnish/libvmod-curl.git
$ cd libvmod-curl
$ ./autogen.sh
$ ./configure VARNISHSRC=$HOME/varnish-3.0.2/
$ make
$ make install

Notes
-----

Take a look to my other repo for configuring WordPress MU and Nginx:

- [WordPress Nginx](https://github.com/aldoborrero/wordpress-nginx)
