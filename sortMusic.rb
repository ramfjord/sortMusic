#!/usr/bin/env ruby

# All the spaces in file names will be replaced with $separator
$separator = '_' 

# If a song has no associated album, it will go in the directory $default_album under the artist
$default_album = "No Album"

# the folder which contains your music library
$library_root = "~/Music/Library"

# characters we won't allow in file names
$invalid_characers = /[^a-zA-Z0-9\s_\-"()]/

# file extensions currently supported
$supported_extension_regex = /\.(mp3|m4a)/

#
# getFMTInfo
# should return a hash with at the following 3 keys:
#   :artist => song artist (fail if it doesn't exist)
#   :album  => song album  ($default_album if it doesn't exist) 
#   :title  => song title  (fail if it doesn't exist)
#

# gets the info hash from an mp3 file, using the progam eyeD3
def getMp3Info(file)
  ret = {}
  tagstrings = `eyeD3 --no-color #{file} | grep -P '(title|artist|album)' | sed 's/\\t\\+/\\n/'`.split("\n")
  tagstrings.each do |line|
    key_val = line.split(":")
    ret[(key_val[0].strip.to_sym)] = key_val[1]
  end
  if ret[:artist].nil? || ret[:album].nil? || ret[:title].nil?
    raise "Error parsing id3 tags on mp3 file - is it possible that eyeD3 output format has changed?"
  end
  ret
end

# gets the info hash from an M4a file, using AtomicParsley
def getMp4Info(file)
  def get_val(string)
    string.split(":")[1]
  end

  ret = {}
  tagstrings = `AtomicParsley #{file} -t | grep -Pi '(art|alb|nam)'`.split("\n")
  ret[:artist] = get_val(tagstrings.grep(/ART" contains/i)[0])
  ret[:title] =  get_val(tagstrings.grep(/nam" contains/i)[0])

  tmp = tagstrings.grep(/alb" contains/i)[0]
  ret[:album] = (tmp.nil?) ? $default_album : tmp.split(":")[1]
  if ret[:artist].nil? || ret[:album].nil? || ret[:title].nil?
    raise "Error parsing m4a tags - is it possible that AtomicParsley output format has changed?"
  end
  ret
end

# Args:
#   info: a hash with at least 3 keys, :artist, :album, and :title
# Modifies the song info however you want before any symlinks/copies are made
def preprocessInfo(info)
  [:artist, :album, :title].each do |key|
    val = info[key]
    # downcase and remove whitespace and single quotes
    val = val.downcase.strip.gsub(/"/, "'")
    # convert all spaces to a single $separator
    val.gsub!(/\s+/, $separator)
    # TODO check better way to capitalize each word
    val = val.split($separator).map { |s| s.capitalize }.join($separator)

    # sanitize any remaining bad characters
    val.gsub!($invalid_characers, "")

    info[key] = val
  end
end

# Args:
#   info: a hash with at least 3 keys, :artist, :album, and :title
# Returns: a string of the path to where we want to put the song
# NOTE: the final song will go in "#{pathFromInfo(info)/#{info[:title]}"
def pathFromInfo(info)
  return "#{$library_root}/#{info[:artist]}/#{info[:album]}"
end

# calls on the shell to
# TODO add option to move or copy
# $ ln -s #{filename} #{desired_path}
def moveSong(file)
  fileinfo = `file #{file}`
  info = nil
  if fileinfo =~ /MPEG.*layer\s*III/ || fileinfo =~ /with\s*ID3/
    info = getMp3Info(file)
  elsif fileinfo =~ /MPEG v4 system/
    info = getMp4Info(file)
  else
    $stderr.puts(fileinfo)
    $stderr.puts "#{file} appears to have an unsupported file type."
    return nil
  end
  preprocessInfo(info)
  path = pathFromInfo(info)
  system("mkdir -p '#{path}'") 
  system("ln -s -f #{file} '#{path}/#{info[:title]}'")
end

ARGV.each do |arg|
  if system("test -d #{arg}")
    # TODO get this to work
    puts "skipping directory #{arg} - directory support forthcoming"
  elsif system("test -f #{arg}")
    $stderr.puts arg
    # TODO do some error checking - and in the end print a list of files which failed
    moveSong(arg)
  end
end
