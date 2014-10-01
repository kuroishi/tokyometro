
require 'httpclient'
require 'sinatra'
require 'yaml'
require 'date'
require 'json'

require 'pp'
require 'syslog'

API_ENDPOINT = 'https://api.tokyometroapp.jp/api/v2/'
DATAPOINTS_URL = API_ENDPOINT + "datapoints"
ACCESS_TOKEN = '746a8dd552c05105f59b37b11d41905349848c20f1586bb9c5e746022ed5efc2'

STATION_LIST = YAML.load_file('stationList.yaml')

def get_stations(station_name)
    result = []
    STATION_LIST.each do |station|
        result << station if station_name == station["name"]                      
    end
    result
end

def get_station_name(odpt_station_name)
    STATION_LIST.each do |station|
        result station["name"] if odpt_station_name == station['odpt_name']
    end
    nil
end

get '/' do
    erb :index
end

post '/' do
    odpt_station_list = get_stations(params[:stationName].gsub("|", ""))

    now = DateTime.now.new_offset(Rational(9, 24))

    @results = []

    unless Syslog.opened? 
        Syslog.open("kuroishi", Syslog::LOG_PID,
                                Syslog::LOG_USER)
    end

    Syslog.log(Syslog::LOG_ERR, odpt_station_list.join(","))

    http_client = HTTPClient.new
    Syslog.log(Syslog::LOG_ERR, "YYY")
    odpt_station_list.each do |station|
        Syslog.log(Syslog::LOG_ERR, "ZZZ")
        response = http_client.get DATAPOINTS_URL, {
                   "rdf:type" => "odpt:StationTimetable",
                   "odpt:station" => station["odpt_name"],
                   "acl:consumerKey" => ACCESS_TOKEN
                   }
        
        Syslog.log(Syslog::LOG_ERR, "%s", response.pretty_inspect)

        JSON.parse(response.body).each do |station_timetable|
            Syslog.log(Syslog::LOG_ERR, "%d", __LINE__)
            timetable = case now.wday
                        when 0
                            station_timetable["odpt:holidays"]
                        when 6
                            station_timetable["odpt:saturdays"]
                        else
                            station_timetable["odpt:weekdays"]
                        end

            timetable.each do |time|
                 hour, min = time["odpt:departureTime"].split(":").map{|num| num.to_i}
                 Syslog.log(Syslog::LOG_ERR, "%d %d %d", __LINE__, hour, min)
                 timetable_datetime = DateTime.new(now.year, now.month, now.day, hour, min, 0, "+9")
                 timetable_datetime.next_day if hour <= 2
                 next if now >= timetable_datetime
                 Syslog.log(Syslog::LOG_ERR, "%d", __LINE__)
                 @results << {"name"=>station["name"],
                     "line_name"=>station["line"],
                     "time"=>time["odpt:departureTime"],
                     "dest"=>get_station_name(time["odpt:destinationStation"])}
                 break
            end
        end
    end
    erb :show
end

set :bind, "0.0.0.0"
set :port, 8880

# Local Variables:
# code: utf-8
# mode: text
# End:
