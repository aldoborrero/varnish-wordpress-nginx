# ------------------------------------------------------------------------------
# Varnish for WordPress (mainly) or whatever you like to use
#
# Inspired by:
#   - https://www.varnish-cache.org/docs/3.0
#   - http://www.linuxforu.com/2012/04/how-to-lock-down-wordpress-admin-access-using-socks5-proxy/
#   - https://github.com/nicolargo/varnish-nginx-wordpress/blob/master/default.vcl
#   - http://blog.bigdinosaur.org/adventures-in-varnish/
#   - https://www.varnish-software.com/static/book/VCL_Basics.html
#   - and myself, fuck!
#
# Use this diagram to understand the phases that Varnish will use:
#   - https://www.varnish-software.com/static/book/_images/vcl.png
#
# Author: Aldo Borrero <aldo@aldoborrero.com>
#
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------

# For serving custom error pages. People don't need to know the fact that I'm using
# Varnish.
import std;

# Redirects made easy
# Remember this module doesn't come by default with Varnish, if you're using
# Ubuntu Server, go to http://serverfault.com/questions/407754/how-to-install-a-varnish-module-on-ubuntu
# to understand how you can make it work!
# GitHub Url: https://github.com/xcir/libvmod-redirect
import redirect;

# Neither this module comes by default with Varnish. Check instructions above.
# GitHub Url: https://github.com/varnish/libvmod-var
import var;

# Set Nginx as default backend (the same applies to Apache or whichever web server you use)
backend nginx {
  .host = "127.0.0.1";
  .port = "8080";
  
  # Health check. Varnish pings every 20 segs. It checks the last 5 responses and if 
  # the last 3 were bad… it will start to fetch objects from the cache. You need to have
  # a virtual-host in nginx ready for this (it's better than pinging to the main virtual host)
  # See https://github.com/aldoborrero/wordpress-nginx/tree/master/sites-available 
  # if you want an example of varnish.local virtual host in Nginx.
  .probe = {
    .window = 5;
    .interval = 5s;
    .threshold = 2;
    .request =
      "GET / HTTP/1.1"
      "Host: varnish.local"
      "Connection: close";
  }
}

# Who is going to purge the cache (localhost)
acl cache_purge {
  "127.0.0.1";
  "localhost";
}

# Enable wp-admin & wp-login only for selected users through a Socks Proxy.
# You should put your external IP address here, only request from that machine
# can pass trough to the backend.
acl allowed_admin_ips {
  "XXX.XXX.XXX.XXX";  # Replace here with your external IP address
}

# ------------------------------------------------------------------------------
# Varnish Config
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Receiving requests from any Browser to Varnish
# ------------------------------------------------------------------------------

sub vcl_recv {

  # ----------------------------------------------------------------------------
  # General Configuration that (should) applies to all domains
  # ----------------------------------------------------------------------------
  
  # Allow the backend to serve up stale content if it is responding slowly.
  set req.grace = 5h;
  
  # Allow to purge the cache to localhost
  if (req.request == "PURGE") {
    if (client.ip ~ cache_purge) {
      # OK, do a cache lookup
      return (lookup);
    }
    error 405 "You're busted!";
  }
  
  # Post requests will not be cached
  if (req.request == "POST") {
    return (pass);
  }
  
  # Remove cookies from most kinds of static objects, since we want
  # all of these things to be cached whenever possible - images, 
  # HTML, JS, CSS, web fonts, and flash. There's also a regex on the
  # end to catch appended version numbers.
  if (req.url ~ "(?i)\.(png|gif|jpeg|jpg|ico|swf|css|js|html|htm|woff|ttf|eot|svg)(\?[a-zA-Z0-9\=\.\-]+)?$") {
    remove req.http.Cookie;
  }
  
  # ----------------------------------------------------------------------------
  # Specific domains configuration
  # ----------------------------------------------------------------------------
  
  # Select to which domains we want to do business with Varnish.
  # Note: It's a wildcard domain, it works for www or wathever you want to put there.
  # I'm using it with WordPress MU
  # Substitute domain.com for your own, please!
  if (req.http.host ~ "^(.*\.)?domain\.com$") {
    
    # WordPress
    # Limit who can access to the admin interface (Remember you should use a SOCKS 
    # proxy in order to get access).
    # More info in: https://calomel.org/firefox_ssh_proxy.html
    if (req.url ~ "wp-(login|admin)" && client.ip ~ allowed_admin_ips) {
      return (pass);
    } else if (req.url ~ "wp-(login|admin)") {
      error(redirect.location(301,"http://aldoborrero.com/"), "Go back dude!");
    }
    
    # Tell Varnish to use X-Forwarded-For, to set "real" IP addresses on all requests.
    remove req.http.X-Forwarded-For;
    set req.http.X-Forwarded-For = req.http.rlnclientipaddr;
    
    # Strip all cookies
    remove req.http.Cookie;
  } # End .domain.com
}

# ------------------------------------------------------------------------------
# Lookup in our cache hash if we have our object there
# ------------------------------------------------------------------------------

# By default you don't need to do nothing here
#sub vcl_hash {
#}

# ------------------------------------------------------------------------------
# Great! We have our page cached. We only have to deal with purging.
# ------------------------------------------------------------------------------

sub vcl_hit {
  if (req.request == "PURGE") {
    purge;
    error 200 "Purged.";
  }
  
  return (deliver);
}

# ------------------------------------------------------------------------------
# Fuck! We don't have our page cached. Same as before.
# ------------------------------------------------------------------------------

sub vcl_miss {
  if (req.request == "PURGE") {
    purge;
    error 200 "Not in cache.";
  }
  
  return (fetch);
}

# ------------------------------------------------------------------------------
# 
# ------------------------------------------------------------------------------

sub vcl_fetch {
  # Allow items to be stale if needed.
  set beresp.grace = 5h;
  
  if (req.http.host ~ "^(.*\.)?domain\.com$") {
    if (!(req.url ~ "wp-(login|admin)")) {
      remove beresp.http.set-cookie;
    }
  }
  
  return (deliver);
}

# ------------------------------------------------------------------------------
# What to do if we passed the cache
# ------------------------------------------------------------------------------

sub vcl_pass {
  set bereq.http.connection = "close";
}

# ------------------------------------------------------------------------------
# Last attempt to do things before we send our page to the browser
# ------------------------------------------------------------------------------

sub vcl_deliver {
  # Clean some headers. I think about security!
  remove resp.http.X-Varnish;
  remove resp.http.Via;
  remove resp.http.Age;
  remove resp.http.X-Powered-By;
  remove resp.http.Server;
  remove resp.http.X-Pingback;
  
  # If we have a curious guy... we suggest him to listen Kavinsky (it's a better 
  # thing to do than staying there looking our headers :P)
  set resp.http.Listen-Kavinsky-Playlist = "http://j.mp/Tyxzaz";
  
  return (deliver);
}
