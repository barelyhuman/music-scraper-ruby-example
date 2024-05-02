# frozen_string_literal: true

require 'json'
require 'httparty'
require 'base64'
require 'uri'

SPOTIFY_API_URL = 'https://accounts.spotify.com/api/token'
SPOTIFY_AUTH_URL = 'https://accounts.spotify.com/authorize'

# docs
class SpotAPI
  @token = ''

  def initialize(client_id, client_secret, redirect_uri)
    @client_id = client_id
    @client_secret = client_secret
    @redirect_uri = redirect_uri
  end

  def get_access_token(code)
    response = HTTParty.post(
      SPOTIFY_API_URL,
      body: {
        grant_type: 'authorization_code',
        code: code,
        redirect_uri: @redirect_uri,
        client_id: @client_id,
        client_secret: @client_secret
      }
    )
    puts response['access_token']
    @token = response['access_token'] if response.code == 200
    @token
  end

  def generate_authorization_url
    query_params = {
      client_id: @client_id,
      response_type: 'code',
      redirect_uri: @redirect_uri,
      scope: 'user-read-private user-read-email playlist-read-private user-library-read playlist-read-collaborative'
    }

    authorization_url = URI.parse(SPOTIFY_AUTH_URL)
    authorization_url.query = URI.encode_www_form(query_params)
    authorization_url.to_s
  end

  def playlists
    response = HTTParty.get(
      'https://api.spotify.com/v1/me/playlists?offset=0&limit=50',
      headers: {
        "Authorization": "Bearer #{@token}"
      }
    )
    response['items'].map do |item|
      { id: item['id'], name: item['name'] }
    end
  end

  def get_playlist_name(id)
    response = HTTParty.get(
      "https://api.spotify.com/v1/playlists/#{id}/",
      headers: {
        "Authorization": "Bearer #{@token}"
      }
    )
    response['name']
  end

  def tracks_by_playlist_id(id)
    response = HTTParty.get(
      "https://api.spotify.com/v1/playlists/#{id}/",
      headers: { "Authorization": "Bearer #{@token}" }
    )
    response['tracks']['items'].map do |item|
      {
        name: item['track']['name'],
        artists: item['track']['artists'].map do |art|
          art['name']
        end
      }
    end
  end
end
