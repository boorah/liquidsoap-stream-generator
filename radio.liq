#!/usr/bin liquidsoap

# Use yt-dlp in place of youtube-dl
settings.protocol.youtube_dl.path.set("yt-dlp");

# Need to create a directory named music with audio files
defaultPlaylist = playlist("./music");
userQueue = request.queue(id="q1");

radio = fallback(track_sensitive=false, [userQueue,defaultPlaylist])

# Output to icecast
output.icecast(%mp3, host="localhost", port=8000,
password="hackme", mount="my-radio.mp3", radio, fallible=true)

last_metadata = ref([])
radio.on_track(fun (m) -> last_metadata := m)

def getMetadata(~protocol, ~headers, ~data, uri)
  try 
    http.response(content_type="application/json; charset=UTF-8",
    data=metadata.json.stringify(!last_metadata))
  catch err do
    log.critical(label="Failed to get metadata","message:#{err.message}, positions:#{err.positions}");

    http.response(content_type="application/json", data=json.stringify({message=err.message}), code=500);
  end
end

def enqueue(~protocol, ~headers, ~data, uri)
  try 
    let json.parse ({
      trackYoutubeUrl
    } : {
      trackYoutubeUrl: string
    }) = data;

    ytdlPrefixedString = 'youtube-dl:#{trackYoutubeUrl}'

    # Add youtube url to the queue
    userQueue.push.uri(ytdlPrefixedString)

    http.response(data=json.stringify({message="success"}))
  catch err do
    log.critical(label="Failed to enqueue track","message:#{err.message}, positions:#{err.positions}");

    http.response(content_type="application/json", data=json.stringify({message=err.message}),code=500)
  end
end

def skip(~protocol, ~headers, ~data, uri)
  try
    radio.skip();
    http.response(data=json.stringify({message="success"}))
  catch err do
    log.critical(label="Failed to skip track","message:#{err.message}, positions:#{err.positions}");

    http.response(content_type="application/json", data=json.stringify({message=err.message}), code=500);
  end
end

harbor.http.register(port=9000, "/enqueue", method="POST", enqueue)
harbor.http.register(port=9000, "/skip", method="POST", skip)
harbor.http.register(port=9000, "/metadata", method="GET", getMetadata)