Check primary URLs:

  $ curl -Is https://javadoc.scijava.org/Micro-Manager-Core/ | head -n1
  HTTP/1.1 200 OK
  $ curl -Is https://javadoc.scijava.org/Micro-Manager-Studio/ | head -n1
  HTTP/1.1 200 OK

Check that trailing slashes are added appropriately:

  $ curl -Is https://javadoc.scijava.org/Micro-Manager-Core | grep '^\(HTTP/\|Location:\)'
  HTTP/1.1 301 Moved Permanently
  Location: https://javadoc.scijava.org/Micro-Manager-Core/
  $ curl -Is https://javadoc.scijava.org/Micro-Manager-Studio | grep '^\(HTTP/\|Location:\)'
  HTTP/1.1 301 Moved Permanently
  Location: https://javadoc.scijava.org/Micro-Manager-Studio/

