
#require 'dm-core'
#require 'dm-validations'
#require 'dm-migrations'
require 'pathname'

module DataLoader
  autoload :ScopeInput, 'data_loader/scope_input'
  autoload :WaveCoverage, 'data_loader/wave_coverage'
  autoload :ErrorPoint, 'data_loader/error_point'

  class << self
    def setup(db_name = 'sea_data', migrate = false, debug = false)
      DataMapper::Logger.new($stdout, :debug) if debug

      DataMapper.setup(:default, 'postgres://localhost/' + db_name)

      if migrate
        ScopeInput.auto_migrate!
        WaveCoverage.auto_migrate!
        ErrorPoint.auto_migrate!
      end
    end

    def process_intercepts(file_name)
      circuit_info = parse_filename(file_name)

      lines = File.readlines(file_name).map {|l| l.rstrip}[9..-1]

      prev_point = { :voltage => 0.0, :time => 0.0 }

      lines.each do |line|
        t, v = line.split(' ')
        t = t.to_f; v = v.to_f

        return if t > 209.5

        if (t > 208.0 && t < 209.12) && (prev_point[:voltage] < 0.0 && v > 0.0)
          intercept = calculate_intercept(prev_point, { :voltage => v, :time => t })
          # 209.12 should be configurable.
          x_intercept = 209.12 - intercept
          WaveCoverage.create(circuit_info.merge({ :x_intercept => x_intercept, :strike_point => 209.12 }))
        end
        prev_point[:voltage] = v
        prev_point[:time] = t
      end
    end

    def process_error_points(file_name)
      circuit_info = parse_filename(file_name)

      lines = File.readlines(file_name).map {|l| l.rstrip}[9..-1]

      max = { :voltage => 0.0, :time => 0.0, :strike_point => 209.12, :type => 'MAX' }
      min = { :voltage => 0.0, :time => 0.0, :strike_point => 209.12, :type => 'MIN' }
      prev_voltage = 0.0

      lines.each do |line|
        t, v = line.split(' ')
        t = t.to_f; v = v.to_f

        next if t < 208.00
        return if t > 211.00

        if (v > max[:voltage] && v > 0.3)
          max[:voltage] = v; max[:time] = t
        end

        if (v < min[:voltage] && v < -0.3)
          min[:voltage] = v; min[:time] = t
        end

        if (prev_voltage >= 0.0 && v < 0.0)
          if max[:voltage] != 0.0 && max[:voltage] < 4.01969118249074
            max[:strike_delta] = (max[:strike_point] - t).abs()
            ErrorPoint.create(circuit_info.merge(max))
          end
          max[:voltage] = max[:time] = 0.0
        end

        if (prev_voltage < 0.0 && v >= 0.0)
          if min[:voltage] != 0.0 && min[:voltage] > -4.14416711437404
            min[:strike_delta] = (min[:strike_point] - t).abs()
            ErrorPoint.create(circuit_info.merge(min))
          end
          min[:voltage] = min[:time] = 0.0
        end
        prev_voltage = v
      end
    end

    # This file is globbed together in 1000 line chunks. ugh...
    def process_ugly_error_points(file_name)
      circuit_info = parse_filename(file_name)
      circuit_info.merge!({ :circuit => 't9t10', :scan => 'avg1' })

      lines = File.readlines(file_name).map {|l| l.rstrip}[9..-1]

      new_zero = 38.17
        #For neg: 37.18
      file_config = { :strike_point => 9.2, :time_increment => 20.0 }
      max = { :voltage => new_zero, :time => 0.0,
        :strike_point => file_config[:strike_point], :type => 'MAX' }
      min = { :voltage => new_zero, :time => 0.0,
        :strike_point => file_config[:strike_point], :type => 'MIN' }
      prev_voltage = 0.0

      lines.each do |line|
        t, v = line.split(' ')
        t = t.to_f; v = v.to_f

        next if t < file_config[:strike_point] - 2.0
        if t > file_config[:strike_point] + 2.0
          circuit_info[:scan].succ!
          file_config[:strike_point] += file_config[:time_increment]
          min[:strike_point] = max[:strike_point] = file_config[:strike_point]
        end

        if (v > max[:voltage] && v > new_zero)
          max[:voltage] = v; max[:time] = t
        end

        if (v < min[:voltage] && v < new_zero)
          min[:voltage] = v; min[:time] = t
        end

        if (prev_voltage >= new_zero && v < new_zero)
          if max[:voltage] != new_zero && max[:voltage] < 49.95
            #For neg: 50.5
            max[:strike_delta] = (max[:strike_point] - t).abs()
            ErrorPoint.create(circuit_info.merge(max))
          end
          max[:voltage] = new_zero; max[:time] = 0.0
        end

        if (prev_voltage < new_zero && v >= new_zero)
          if min[:voltage] != new_zero && min[:voltage] > 27.16
            #For neg: 23.8
            min[:strike_delta] = (min[:strike_point] - t).abs()
            ErrorPoint.create(circuit_info.merge(min))
          end
          max[:voltage] = new_zero; max[:time] = 0.0
        end
        prev_voltage = v
      end
    end
 
    def process_new_ugly_error_points(file_name)
      circuit_info = parse_filename(file_name)
      circuit_info.merge!({ :circuit => 'RXamp', :scan => 'sim' })

      lines = File.readlines(file_name).map {|l| l.rstrip}[10..-1]

      prev_point = { :voltage => 0.0, :time => 94.98e-9 }
      prev_int = 94.99e-9
      new_zero = 0.0 
      file_config = { :strike_point => 100e-9, :time_increment => 3.2e-9 }
      max = { :voltage => new_zero, :time => 0.0,
        :strike_point => file_config[:strike_point], :type => 'MAX' }
      min = { :voltage => new_zero, :time => 0.0,
        :strike_point => file_config[:strike_point], :type => 'MIN' }
      prev_voltage = 0.0

      lines.each do |line|
        c, t, v1, v2 = line.split(' ')
        t = t.to_f; v1 = v1.to_f; v2 = v2.to_f
        v = v1 - v2

        if (prev_point[:voltage] < 0.0 && v >= 0.0)
          intercept = calculate_intercept(prev_point, { :voltage => v, :time => t })
          jitter = intercept - prev_int
          print "Jitter= ",jitter,"\n"
          if (jitter >= 640e-12 or jitter <= 640e-12)
            ErrorPoint.create(circuit_info.merge({ :x_intercept => jitter, :strike_point => t }))
          end
          prev_int = intercept
        end
        prev_point[:voltage] = v
        prev_point[:time] = t

        next if t < file_config[:strike_point] - 160e-12 
        if t > file_config[:strike_point] + 2.56e-12
          circuit_info[:scan].succ!
          file_config[:strike_point] += file_config[:time_increment]
          min[:strike_point] = max[:strike_point] = file_config[:strike_point]
        end

        if (v > max[:voltage] && v > new_zero)
          max[:voltage] = v; max[:time] = t
        end

        if (v < min[:voltage] && v < new_zero)
          min[:voltage] = v; min[:time] = t
        end

        if (prev_voltage >= new_zero && v < new_zero)
          if max[:voltage] != new_zero && max[:voltage] < 0.5 
            #For neg: 50.5   For pos: 49.95
            max[:strike_delta] = (max[:strike_point] - t).abs()
            ErrorPoint.create(circuit_info.merge(max))
          end
          max[:voltage] = new_zero; max[:time] = 0.0
        end

        if (prev_voltage < new_zero && v >= new_zero)
          if min[:voltage] != new_zero && min[:voltage] > -0.5 
            #For neg: 23.8   For pos: 27.16
            min[:strike_delta] = (min[:strike_point] - t).abs()
            ErrorPoint.create(circuit_info.merge(min))
          end
          max[:voltage] = new_zero; max[:time] = 0.0
        end
        prev_voltage = v
      end
    end
    def process_daniel_intercepts(file_name)
      circuit_info = parse_filename(file_name)
      circuit_info.merge!({ :circuit => 'RXamp' })

      lines = File.readlines(file_name).map {|l| l.rstrip}[9..-1]

      prev_point = { :voltage => 0.0, :time => 94.98e-9 }
      prev_int = 94.99e-9

      lines.each do |line|
        c, t, v1, v2 = line.split(' ')
        t = t.to_f; v1 = v1.to_f; v2 = v2.to_f
        v = (v1 - v2)

        if (prev_point[:voltage] < 0.0 && v >= 0.0)
          intercept = calculate_intercept(prev_point, { :voltage => v, :time => t })
          jitter = intercept - prev_int
          if (jitter >= 768e-12 or jitter <= 512e-12)
            ErrorPoint.create(circuit_info.merge({ :x_intercept => jitter, :strike_point => t }))
          end
          prev_int = intercept
        end
        prev_point[:voltage] = v
        prev_point[:time] = t
      end
    end

    def parse_filename(file_name)
      root = Pathname.new(file_name).basename.to_s.gsub(/.raw/, '')
      tokens = root.split('-')

      case tokens.size
        when 2
          { :pixel => tokens[0], :energy => tokens[1] }
        when 3
          { :circuit => 'RXamp',
            :pixel => tokens[0], :energy => tokens[1] }
        when 4
          { :circuit => tokens[0], :energy => tokens[1],
            :pixel => tokens[2], :scan => tokens[3] }
        when 5
          { :circuit => tokens[0], :energy => tokens[1],
            :pixel => tokens[3], :scan => tokens[4] }
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
