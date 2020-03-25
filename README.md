# Suss

Example using Ashen to create an interactive cUrl-like application.  You can run the app with no arguments, when you exit (`Esc`) it will output the equivalent command line arguments to "restore" your session.

Press `Enter` from the URL or Method fields to send the request, or `ctrl+o` from any input

![Screenshot of Suss in action](http://media.colinta.com/ashen/screenshot.png)

Parses command line options using [Swift Argument Parser](https://github.com/apple/swift-argument-parser).

```
suss [URL] \
    -X (get,post,put,patch,delete,head,options) \
    -p key=value \  # url query parameter
    [-p ...] \
    --data [one line of POST data] \
    [--data ...]
    -H 'header: value' \
    [-H ...]

# example
suss https://maps.googleapis.com/maps/api/place/nearbysearch/json \
    -X GET \
    -p type=grocery_or_supermarket \
    -p location=35.628750,-82.544296 \
    -p radius=40000 \
    -p key=qwfpgjluyarstdhneiozxcvbkm12345678...
```

Creates a session that looks like this:

```
┌─URL────────────────────────────────────────────────────────────────────────────────────────────────────
│https://maps.googleapis.com/maps/api/place/nearbysearch/json

┌─Method───────────────────────────────┌─Response headers────────────────────────────────────────────────
│GET POST PUT PATCH DELETE HEAD OPTIONS│Status-code: 200
 ---                                   │Vary: Accept-Language
┌─GET Parameters───────────────────────│Date: Tue, 24 Mar 2020 20:00:37 GMT
│type=grocery_or_supermarket           │Server: scaffolding on HTTPServer2
│location=35.628750,-82.544296         │x-frame-options: SAMEORIGIN
│radius=40000                          │Expires: Fri, 01 Jan 1990 00:00:00 GMT
│key=qwfpgjluyarstdhneiozxcvbkm12345678│x-xss-protection: 0
│                                      │server-timing: gfet4t7; dur=12
│                                      │Pragma: no-cache
│                                      ┌─Response body───────────────────────────────────────────────────
┌─POST Body────────────────────────────│{
│                                      │   "error_message" : "The provided API key is invalid.",
│                                      │   "html_attributions" : [],
│                                      │   "results" : [],
│                                      │   "status" : "REQUEST_DENIED"
│                                      │}
│                                      │
┌─Headers──────────────────────────────│EOF
│                                      │
│                                      │
│                                      │
│                                      │
│                                      │
│                                      │
[Suss v1.0.0] https://maps.googleapis.com/maps/api/place/nearbysearch/json?type=grocery%5For%5Fsupermarke

```
