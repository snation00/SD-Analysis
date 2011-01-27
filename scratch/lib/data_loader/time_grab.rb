#1. Read in files, one at a time (remove first 10 junk lines)
#2. Start looking at data at 90 ns...strikes start at 100ns
#3. Raise flag if output drops below 90% of max (1 V) and record time (t1)
#4. If the flag is raised, record time (t2) when output goes back above 90%
#5. Reset flag
#6. Record t2-t1
#7. Ouput Node name, LET, number of flags in file, duration and time of flags

module DataLoader
  def self.grab_time(file_name)
    circuit_info = parse_filename(file_name)
    lines = File.readlines(file_name).map {|l| l.rstrip}[9..-1]
    strike_start = 90e-9
    max_voltage = 1.0
    strike_count = 0
    t1 = time_delta = 0.0

    lines.each do |line|
      _, t, _, v = line.split(' ')
      t = t.to_f; v = v.to_f

      next if t < strike_start
      if v < max_voltage * 0.9
        strike_count++
        t1 = t
        time_delta = 0.0
      end

      if t1 > 0.0 and v >= max_voltage * 0.9
        time_delta = t1 - t
        puts circuit_info.merge({
          :time_delta => time_delta,
          :strike_count => strike_count
        }).inspect
        t1 = 0.0
      end
    end
  end

  def self.parse_filename(file_name)
    root = Pathname.new(file_name).basename.to_s.gsub(/.raw/, '')
    tokens = root.split('-')

    case tokens.size
      when 2
        { :node => tokens[0], :energy => tokens[1] }
      else
        { }
    end
  end
end
