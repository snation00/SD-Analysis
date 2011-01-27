#!/usr/bin/env ruby

# -*- encoding: utf-8 -*-
require 'rubygems'

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'data_loader'

# The dir is relative to where you are running your script
dir = './comp/'
dir = ARGV[0] if ARGV[0]

Dir.glob(dir + '*.raw') do |file_name|
  DataLoader::grab_time(file_name)
end
