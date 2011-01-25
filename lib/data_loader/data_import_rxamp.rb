#!/usr/bin/env ruby

# -*- encoding: utf-8 -*-
require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

# $:.unshift('./lib')
$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'data_loader'

DataLoader.setup('hss_sim', true)

dir = './data/'
dir = ARGV[0] if ARGV[0]

Dir.glob(dir + '*.raw') do |file_name|
  # DataLoader::process_file(file_name)
  # DataLoader::process_intercepts(file_name)
  # DataLoader::process_error_points(file_name)
  # DataLoader::process_ugly_error_points(file_name)
  DataLoader::process_new_ugly_error_points(file_name)
  # DataLoader::process_daniel_intercepts(file_name)
end
