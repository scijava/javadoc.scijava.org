Check primary URLs:

  $ curl -Is https://javadoc.scijava.org/Eclipse/ | head -n1
  HTTP/1.1 302 Found

Check that trailing slashes are added appropriately:

  $ curl -Is https://javadoc.scijava.org/Eclipse | grep '^\(HTTP/\|Location:\)'
  HTTP/1.1 301 Moved Permanently
  Location: https://javadoc.scijava.org/Eclipse/

