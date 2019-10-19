Check primary URLs:

  $ curl -Is https://javadoc.scijava.org/Java6/ | head -n1
  HTTP/1.1 200 OK
  $ curl -Is https://javadoc.scijava.org/Java7/ | head -n1
  HTTP/1.1 200 OK
  $ curl -Is https://javadoc.scijava.org/Java8/ | head -n1
  HTTP/1.1 200 OK
  $ curl -Is https://javadoc.scijava.org/Java9/ | head -n1
  HTTP/1.1 200 OK
  $ curl -Is https://javadoc.scijava.org/Java10/ | head -n1
  HTTP/1.1 200 OK
  $ curl -Is https://javadoc.scijava.org/Java11/ | head -n1
  HTTP/1.1 200 OK
  $ curl -Is https://javadoc.scijava.org/Java12/ | head -n1
  HTTP/1.1 200 OK
  $ curl -Is https://javadoc.scijava.org/Java13/ | head -n1
  HTTP/1.1 200 OK

Check secondary aliases:

  $ curl -Is https://javadoc.scijava.org/Java/ | head -n1
  HTTP/1.1 200 OK

Check that trailing slashes are added appropriately:

  $ curl -Is https://javadoc.scijava.org/Java6 | grep '^\(HTTP/\|Location:\)'
  HTTP/1.1 301 Moved Permanently
  Location: https://javadoc.scijava.org/Java6/
  $ curl -Is https://javadoc.scijava.org/Java7 | grep '^\(HTTP/\|Location:\)'
  HTTP/1.1 301 Moved Permanently
  Location: https://javadoc.scijava.org/Java7/
  $ curl -Is https://javadoc.scijava.org/Java8 | grep '^\(HTTP/\|Location:\)'
  HTTP/1.1 301 Moved Permanently
  Location: https://javadoc.scijava.org/Java8/
  $ curl -Is https://javadoc.scijava.org/Java9 | grep '^\(HTTP/\|Location:\)'
  HTTP/1.1 301 Moved Permanently
  Location: https://javadoc.scijava.org/Java9/
  $ curl -Is https://javadoc.scijava.org/Java10 | grep '^\(HTTP/\|Location:\)'
  HTTP/1.1 301 Moved Permanently
  Location: https://javadoc.scijava.org/Java10/
  $ curl -Is https://javadoc.scijava.org/Java11 | grep '^\(HTTP/\|Location:\)'
  HTTP/1.1 301 Moved Permanently
  Location: https://javadoc.scijava.org/Java11/
  $ curl -Is https://javadoc.scijava.org/Java12 | grep '^\(HTTP/\|Location:\)'
  HTTP/1.1 301 Moved Permanently
  Location: https://javadoc.scijava.org/Java12/
  $ curl -Is https://javadoc.scijava.org/Java13 | grep '^\(HTTP/\|Location:\)'
  HTTP/1.1 301 Moved Permanently
  Location: https://javadoc.scijava.org/Java13/

