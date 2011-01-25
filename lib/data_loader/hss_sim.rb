# encoding: utf-8

module DataLoader
  class HssSim
    include DataMapper::Resource
    storage_names[:default] = 'hss_sims'

    # t9t10 --> the circuit that was scanned...in the case, all will be t9t10 (a string)
    # high --> laser pulse energy (also a string)
    # 1012 --> the pixel number...when in the scan the file was made (int)
    # avg1 --> the scan number as: avg#. In this case it's always integers 1-5.

    property :id,           Serial
    property :circuit,      String, :required => true, :index => true
    property :period,       Float, :index => true
    property :jitter_time,  Float
    property :energy,       String
    property :node,        Integer, :index => true
    property :bit_miss_v,     Float
    property :miss_time,    Float
    property :type,         String
  end
end
