
#require 'dm-core'
#require 'dm-validations'
#require 'dm-migrations'
require 'pathname'

module DataLoader
  autoload :TXampSim, 'data_loader/txamp_sim'

  class << self
    def setup(db_name = 'sea_data', migrate = false, debug = false)
      DataMapper::Logger.new($stdout, :debug) if debug

      DataMapper.setup(:default, 'postgres://localhost/' + db_name)

      if migrate
        TXampSim.auto_migrate!
      end
    end

    def process_new_ugly_error_points(file_name)
      circuit_info = parse_filename(file_name)
      circuit_info.merge!({ :circuit => 'TXamp' })

      lines = File.readlines(file_name).map {|l| l.rstrip}[10..-1]

      prev_point = { :voltage => 0.0, :time => 44.98e-9 }
      prev_int = 44.99e-9
      new_zero = 0.0 
      file_config = { :cycle_start => 50e-9, :time_increment => 3.2e-9 }
      max = { :bit_miss_v => new_zero, 
        :miss_time => file_config[:cycle_start], :type => 'MAX' }
      min = { :bit_miss_v => new_zero, 
        :miss_time => file_config[:cycle_start], :type => 'MIN' }
      prev_voltage = 0.0

      lines.each do |line|
        c, t, v1, v2 = line.split(' ')
        t = t.to_f; v1 = v1.to_f; v2 = v2.to_f
        v = v1 - v2

        if (prev_point[:voltage] < 0.0 && v >= 0.0)
          intercept = calculate_intercept(prev_point, { :voltage => v, :time => t })
          jitter = intercept - prev_int
          if (jitter >= 768e-12 or jitter <= 512e-12 and t >= 4.9e-8)
            wc = TXampSim.create(circuit_info.merge({ :period => jitter, :jitter_time => t }))
            puts "error: #{wc.errors.full_messages}" unless wc.valid?
          end
          prev_int = intercept
        end
        prev_point[:voltage] = v
        prev_point[:time] = t

        if t > file_config[:cycle_start] + 2.56e-12
          file_config[:cycle_start] += file_config[:time_increment]
          min[:miss_time] = max[:miss_time] = file_config[:cycle_start]
        end

        if (v > max[:bit_miss_v] && v > new_zero)
          max[:bit_miss_v] = v; max[:miss_time] = t
        end

        if (v < min[:bit_miss_v] && v < new_zero)
          min[:bit_miss_v] = v; min[:miss_time] = t
        end

        if (prev_voltage >= new_zero && v < new_zero)
          if max[:bit_miss_v] != new_zero && max[:bit_miss_v] < 0.5 
            #For neg: 50.5   For pos: 49.95
            #max[:bit_miss_v] = (max[:miss_time] - t).abs()
            hs = TXampSim.create(circuit_info.merge(max))
            puts "error: #{hs.errors.full_messages}" unless hs.valid?
          end
          max[:bit_miss_v] = new_zero; max[:miss_time] = 0.0
        end

        if (prev_voltage < new_zero && v >= new_zero)
          if min[:bit_miss_v] != new_zero && min[:bit_miss_v] > -0.5 
            #For neg: 23.8   For pos: 27.16
            #min[:bit_miss_v] = (min[:miss_time] - t).abs()
            TXampSim.create(circuit_info.merge(min))
          end
          max[:bit_miss_v] = new_zero; max[:miss_time] = 0.0
        end
        prev_voltage = v
      end
    end

    def parse_filename(file_name)
      root = Pathname.new(file_name).basename.to_s.gsub(/.raw/, '')
      tokens = root.split('-')

      case tokens.size
        when 2
          { :node => tokens[0], :energy => tokens[1] }
        when 3
          { :circuit => 'RXamp',
            :node => tokens[0], :energy => tokens[1] }
        when 4
          { :circuit => tokens[0], :energy => tokens[1],
            :node => tokens[2], :scan => tokens[3] }
        when 5
          { :circuit => tokens[0], :energy => tokens[1],
            :node => tokens[3], :scan => tokens[4] }
        else
          { }
      end
    end

    def point_delta(min, max)
      time_delta = (min[:time].abs() - max[:time].abs()).abs()
      voltage_delta = (max[:voltage].abs() - min[:voltage].abs()).abs()
      # TODO: the thresholds should be configurable
      time_threshold = 0.4
      voltage_threshold = 2.0
      return (time_delta > time_threshold) && (voltage_delta < voltage_threshold)
    end

    def calculate_intercept(point1, point2)
      slope = (point2[:voltage] - point1[:voltage]) / (point2[:time] - point1[:time])
      b = point2[:voltage] - point2[:time] * slope
      return (-b) / slope
    end
  end
end
