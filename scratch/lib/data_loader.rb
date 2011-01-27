require 'pathname'

module DataLoader
  require 'data_loader/time_grab'

  def self.point_delta(min, max)
    time_delta = (min[:time].abs() - max[:time].abs()).abs()
    voltage_delta = (max[:voltage].abs() - min[:voltage].abs()).abs()
    # TODO: the thresholds should be configurable
    time_threshold = 0.4
    voltage_threshold = 2.0
    return (time_delta > time_threshold) && (voltage_delta < voltage_threshold)
  end

  def self.calculate_intercept(point1, point2)
    slope = (point2[:voltage] - point1[:voltage]) / (point2[:time] - point1[:time])
    b = point2[:voltage] - point2[:time] * slope
    return (-b) / slope
  end
end
