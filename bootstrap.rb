# coding: utf-8

require 'rubygems'
require 'sinatra'
require 'data_mapper'
require 'sass'
#require 'carrierwave'
#require 'carrierwave/datamapper'
#require 'fog'
#require 'paperclip'
#require 'dm-paperclip'
#require 'aws-s3'
require 'aws/s3'

set :bucket, 'MYFIRSTBUCKETS'
set :s3_key, 'AKIAJ533TM552SWWNZFA'
set :s3_secret, '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'

DataMapper.setup(:default, ENV['DATABASE_URL'] || 'sqlite:./db/page.db')

class Page
  include DataMapper::Resource

  property :id,               Serial
  property :name,             String
  property :alias,            String
  property :short,            Text
  property :full,             Text
  property :seo_title,        String, :length=>255
  property :seo_keywords,     String, :length=>255
  property :seo_description,  String, :length=>255
  property :created_at,       DateTime
  property :updated_at,       DateTime
end

#DataMapper.finalize
DataMapper.auto_migrate

##migration( 1, :add_my_image_paperclip_fields ) do
#up do
#    modify_table :my_image do
#      add_column :image_file_name, "varchar(255)"
#      add_column :image_content_type, "varchar(255)"
#      add_column :image_file_size, "integer"
#      add_column :image_updated_at, "datetime"
#    end
#  end
#  down do
#    modify_table :my_image do
#      drop_columns :image_file_name, :image_content_type, :image_file_size, :image_updated_at
#    end
#  end
#end

class MyImage
  include DataMapper::Resource

  property :id,               Serial
  property :image,             String, :length=>255

  #include Paperclip::Resource
  #property :id, Serial
  #property :falename, String
  #has_attached_file :image,
  #                  :storage => :s3,
  #                  :bucket => 'MYFIRSTBUCKETS', #ENV['S3_BUCKET_NAME'],
  #                  :s3_credentials => {
  #                    :access_key_id => 'AKIAJ533TM552SWWNZFA', #ENV['AWS_ACCESS_KEY_ID'],
  #                    :secret_access_key => '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' #ENV['AWS_SECRET_ACCESS_KEY']
  #                  },
  #                  :styles => { :medium => "300x300>",
  #                               :thumb => "100x100>" }
end

#Paperclip.configure do |config|
  #config.root               = Rails.root # the application root to anchor relative urls (defaults to Dir.pwd)
  #config.env                = Rails.env  # server env support, defaults to ENV['RACK_ENV'] or 'development'
  #config.use_dm_validations = false       # validate attachment sizes and such, defaults to false
  #config.processors_path    = 'lib/pc'   # relative path to look for processors, defaults to 'lib/paperclip_processors'
#end

#конфигурация carrierwave
#CarrierWave.configure do |config|
#  config.fog_credentials = {
#    :provider               => 'AWS',       # required
#    :aws_access_key_id      => 'AKIAJ533TM552SWWNZFA',       # required
#    :aws_secret_access_key  => '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',       # required
#    :region                 => 'eu-west-1'  # optional, defaults to 'us-east-1'
#  }
#  config.fog_directory  = 'MYFIRSTBUCKETS'                     # required
#  #config.fog_host       = 'https://assets.example.com'            # optional, defaults to nil
#  config.fog_public     = false                                   # optional, defaults to true
#  config.fog_attributes = {'Cache-Control'=>'max-age=315576000'}  # optional, defaults to {}
#end

#class ImageUploader < CarrierWave::Uploader::Base
#  include CarrierWave::MiniMagick
#  storage :fog #:file

  #def store_dir 
  #  "uploads/images/" 
  #end

  #def cache_dir
  #  "uploads/tmp/"
  #end

  #process :resize_to_fit => [600,600]

  #version :thumb do
  #  process :resize_to_fill => [100,100]
  #end
#end

#class MyImage
#  include DataMapper::Resource
#  property :id, Serial
  #property :image, String, :auto_validation => false
#  mount_uploader :image, ImageUploader #, type: String
#end

#Sinatra configuration
set :public_directory, './public'

get '/stylesheet.css' do
  sass :stylesheet, :style => :expanded
end

#helpers
helpers do
  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Cms's restricted area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.username && @auth.credentials == ['admin', 'password']
  end
end

before '/admin/*' do
  protected!
  @default_layout = :admin
end

#create
get '/admin/create' do
  erb :create_form 
end

get '/admin/edit/:id' do
  # fill form
  @page = Page.get(params[:id])
  erb :edit_form
end

post '/admin/edit/:id' do
  @page = Page.get(params[:id])
  #params.delete 'submit'
  #params.delete 'id'
  #params.delete 'splat'
  #params.delete 'captures' 
  #params[:updated_at] = Time.now
  #@page.attributes = params
  @page.name = params[:name]
  @page.alias = params[:alias]
  @page.short = params[:short]
  @page.full = params[:full]
  @page.seo_title = params[:seo_title]
  @page.seo_keywords = params[:seo_keywords]
  @page.seo_description = params[:seo_description]
  @page.updated_at = Time.now
  @page.save
  redirect '/admin/pages'
end

post '/admin/create' do
  params.delete 'submit'
  params[:updated_at] = params[:created_at] = Time.now
  @page = Page.create(params) 
  redirect '/admin/pages'
end

get '/admin/pages' do
  @pages = Page.all
  erb :pages
end

#deleting
get '/admin/delete/:id' do
  Page.get(params[:id]).destroy
  redirect '/admin/pages'
end

post '/tests/upload.php' do
  unless params[:file] && (tmpfile = params[:file][:tempfile]) && (name = params[:file][:filename])
    return puts 'error'
  end
  while blk = tmpfile.read(65536)
    AWS::S3::Base.establish_connection!(
    :access_key_id     => settings.s3_key,
    :secret_access_key => settings.s3_secret)
    AWS::S3::S3Object.store(name,open(tmpfile),settings.bucket,:access => :public_read)     
  end
  
  AWS::S3::Base.establish_connection!(
      :access_key_id     => settings.s3_key,
      :secret_access_key => settings.s3_secret)
  
  @image = MyImage.new
  puts 'new image'
  @image.image = AWS::S3::S3Object.find(params[:file][:filename], settings.bucket).url #params[:file] #загрузка изображения
  puts 'create image'
  #puts "#{@image.image.url}"
  @image.save
  puts 'save image'
  #@image.reload
  #puts 'reload image'
  #content_type 'image/jpg'
  #img = File.read(@image.image.current_path)
  #img.format = 'jpg'
  #img.to_blob
  #для версии 5 возвращается только путь
  #return @image.image.url

  #content_type @image.image.content_type #'image/jpg'
  #@image.image.read()

  #img = Magick::Image.read(@image.image.current_path)[0]
  #img = File.open(@image.image.current_path)
  #content_type 'image/jpg'
  #img.read
  #img.format = 'jpg'
  #img.to_blob

  #для отправки файла целиком
  #send_file @image.image.current_path, :filename => @image.image.filename, :type => 'image/jpeg'

  "<img src=#{@image.image} />"

  #"<img src=#{@image.image.url} />"
end

get '/tests/images.json' do
  content = '['
  MyImage.all.each do |img|
    content += '{"thumb": "'
    content += img.image#.thumb.url
    content += '", "image": "'
    content += img.image#.url
    content += '"},'
  end
  content = content[0,content.length-1]
  content += ']'
  content
end

get '/' do
  @page = Page.first(:alias => 'mainpage')
  @pages = Page.all(:alias.not => 'mainpage')
  haml :page
end

get '/:alias.html' do
  @page = Page.first(:alias => params[:alias])
  not_found 'Страница не найдена' if @page.nil?
  @pages = Page.all(:alias.not => 'mainpage')
  haml :page
end



not_found do
  erb :'404', {:layout => false}
end
