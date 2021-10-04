Check primary URLs:

  $ curl -Is https://javadoc.scijava.org/ImageJ/ | head -n1
  HTTP/1.1 200 OK
  $ curl -Is https://javadoc.scijava.org/ImageJ1/ | grep '^\(HTTP/\|Location:\)'
  HTTP/1.1 301 Moved Permanently
  Location: https://imagej.nih.gov/ij/developer/api/

Check secondary aliases:

  $ curl -Is https://javadoc.scijava.org/ImageJ2/ | grep '^\(HTTP/\|Location:\)'
  HTTP/1.1 301 Moved Permanently
  Location: https://javadoc.scijava.org/ImageJ/

Check that trailing slashes are added appropriately:

  $ curl -Is https://javadoc.scijava.org/ImageJ | grep '^\(HTTP/\|Location:\)'
  HTTP/1.1 301 Moved Permanently
  Location: https://javadoc.scijava.org/ImageJ/
  $ curl -Is https://javadoc.scijava.org/ImageJ1 | grep '^\(HTTP/\|Location:\)'
  HTTP/1.1 301 Moved Permanently
  Location: https://javadoc.scijava.org/ImageJ1/

Test correctness of ImageJ "catch-all" redirects:

  $ curl -Is https://javadoc.scijava.org/ImageJ1000/ | head -n1
  HTTP/1.1 404 Not Found
  $ curl -Is https://javadoc.scijava.org/ImageJ2000/ | head -n1
  HTTP/1.1 404 Not Found
  $ curl -Is https://javadoc.scijava.org/ImageJ3000/ | head -n1
  HTTP/1.1 404 Not Found
  $ curl -Is https://javadoc.scijava.org/ImageJ3/ | head -n1
  HTTP/1.1 404 Not Found
