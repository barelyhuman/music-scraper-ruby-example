# frozen_string_literal: true

require 'httparty'
require 'bundler'
Bundler.require
require 'dotenv/load'
require 'sinatra'
require 'uri'
require './lib/spotify'

client_id = ENV['SPOTIFY_CLIENT_ID']
client_secret = ENV['SPOTIFY_CLIENT_SECRET']
redirect_uri = ENV['SPOTIFY_REDIRECT_URI']
spotapi = SpotAPI.new(client_id, client_secret, redirect_uri)

def get_search_html(query = '')
  uri = URI('https://vid.puffyan.us/search')
  uri.query = "q=#{query}"
  response = HTTParty.get(uri)
  if response.code == 200
    response.body
  else
    ''
  end
end

def get_result(cards = [])
  cards.each do |data_card|
    elm = data_card.css('a')
    next unless !elm.nil? && elm[0]

    link = elm[0]['href']
    return {
      name: elm.css('p').text,
      link: link
    }
  end
end

def search(query = '')
  html_doc = Nokogiri::HTML(get_search_html(query))
  get_result(html_doc.css('.video-card-row'))
end

# queue
q = Queue.new
Thread.new do
  while (query_data = q.deq) # wait for nil to break loop
    begin
      url_info = search(query_data[:search])
      puts "Downloading: #{url_info[:name]} with #{url_info[:link]}"
      YoutubeDL.download("https://youtube.com/#{url_info[:link]}",
                         extract_audio: true,
                         audio_format: 'mp3',
                         paths: "./downloads/#{query_data[:playlist_name]}").call
    rescue StandardError
      # do nothing
    end

  end
end

# Sinatra

get '/download/:playlist' do
  playlist_id = params['playlist']
  tracks = spotapi.tracks_by_playlist_id(playlist_id).map
  playlist_name = spotapi.get_playlist_name(playlist_id)
  tracks.each do |track|
    q << {
      search: "#{track[:name]} #{track[:artists]}",
      playlist_name: playlist_name
    }
  end
  "downloading...
  you can now close the window and monitor on the terminal"
end

get '/playlists' do
  @playlists = spotapi.playlists
  erb :playlists, layout: 'layouts/base'.to_sym
end

get '/connect/spotify' do
  code = params['code']
  spotapi.get_access_token(code)
  redirect '/playlists', 303
end

get '/' do
  @auth_url = spotapi.generate_authorization_url
  erb :index, layout: 'layouts/base'.to_sym
end
