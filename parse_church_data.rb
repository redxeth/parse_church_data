#require 'rubygems'
require 'optparse'
require 'csv'
require 'Indirizzo'
#require 'logger'

# -- parse_church_data.rb <filename.csv>--
#
# Purpose:
#  Read in St. Paul family/elder/address data
#  provided by church secretary and generate
#  CSV ready to import into Google Maps for map creation
#
# Data is provided as 3 fundamental columns of data
#  step 1: - put everything into a single column
#  step 2: - transpose data to every 4th
#
#  Outputs CSV to display, capture to file if desired

def define_csv_format(options={})
  
  ###############################
  # QUALITIES OF INPUT CSV FILE
  
  # indicate which columns contain valid data
  # leftmost column is 0
  @data_columns = [0,4,8]
 
  # number of lines per group in input file
  @num_lines_per_linegroup = 5
  
  # indicate what values per row
  # should be 0 to @num_lines_per_linegroup-1
  @input_data_rows = {0 => :name,
                      1 => :elder,
                      2 => :address,
                      3 => :city_state_zip,       # occasionally this is more of the address
                      4 => :extra,                # occasionally this is the city/state/zip! 
  }
  
  # Output data fields
  # Used as data for Google Maps,
  # and used to access data itself via keys
  @output_fields = {:name => "Name",                             # key matches @input_data_rows
                    :elder => "Elder",                           # key matches @input_data_rows
                    :address => "Address",                       # key matches @input_data_rows
                    :city_state_zip => "City_State_Zip",         # key matches @input_data_rows
                    :city => "City",                             # generated from city_state_zip above
                    :state => "State",                           # generated from city_state_zip above
                    :zip => "Zip",                               # generated from city_state_zip above
                    :area => "Area",                             # generated based on zip code
                    }
  
  # Hash here used to give warning if someone is assigned to wrong elder!
  # also should match data input -- eventually want this to come from external file?
  @elders = ["Daniel Hadad",
             "Mark De Young",
             "Ernie Johnson",
             "Joshua Konkle",
             "Charles Whitsel",
             "Ethan Cruz",
             "Ross Davis",
             "Don Hilsberg",
             "Paul Hunt",
             "Gary Jordan",
             "Tim Horn",
             "Kelly Holligan",
             "Steve Hutton",
             "John Ritchie",
             ]
  
  # extra list of names to help find elders themselves in the database (need to use hash above instead...)
  # or break down the name to remove spouse name
  @elders2 = ["Dan Hadad",
              ]
  
  # if needing to sub elder in the data
  # format:   old_elder => new_elder
  @elder_sub = {
                }
  
  ###############################
  
end

#
# Simple print of @final_data for debug
#
def print_data(options={})
  # print data by :
  #  :record (default), record, showing each field
  options={:by => :record,
          }.merge(options)
  
  case options[:by]
  when :record
    @final_data.each do |record|
      record.each do |field, value|
        if !field.nil? and !value.nil?
          puts "    #{field}: #{value}" if !field.nil?
        end
      end
      puts "****************************"
    end
  when :zip_code

    # gather all zip codes and count members in each
    all_zips = {}
    @final_data.each do |record|
      unless record[:zip].nil?
        if !all_zips.has_key?(record[:zip])
          # new zip code found
          all_zips[record[:zip]] = 1
        else
          # increment number for previous zip code
          all_zips[record[:zip]] = all_zips[record[:zip]] + 1
        end
      end
    end

    # output data
    puts CSV.generate_line(Array["Zipcode","Count"])
    all_zips.keys.sort.each do |zip|
      count = all_zips[zip]
     # puts " #{zip}  #{count}\n"
      puts CSV.generate_line(Array[zip,count])
    end
 
  when :area
    no_area_assigned = false
    if @command_options[:noaddr]
      puts CSV.generate_line(Array["Area","Family"])
    else
      puts CSV.generate_line(Array["Area","Family","Address","City","State","Zip"])
    end
    @area_zips.keys.each do |area|
      @final_data.each do |record|
        unless record[:name].nil?
          if record[:area] == area
            @area_zips[area] = @area_zips[area] + 1
            if @command_options[:noaddr]
              puts CSV.generate_line(Array[area,record[:name]])
            else
              puts CSV.generate_line(Array[area,record[:name],record[:address],record[:city],record[:state],record[:zip]])
            end
          end
          if record[:area] == :austin
            no_area_assigned = true
          end
        end
      end
    end
    puts "\nWARNING:  Folks in Austin not assigned to area!!" if no_area_assigned

if 1 == 0

    puts "*****************"
    puts CSV.generate_line(Array["AREA","COUNT"])
    @area_zips.keys.each do |area|
      puts CSV.generate_line(Array[area,@area_zips[area]])
    end
end

  else
    fail "ERROR in print_datoa"
  end
  
end

#
# prints final data in google map input format
# to console, grab to file if you like
#
# google.com/mymaps
#
def print_google_map_data(options={})
  options={ header: false,
          }.merge(options)
  
  puts CSV.generate_line(@output_fields.values) if options[:header]
  
  
  @final_data.each do |record|
    if @command_options[:elders_only]
      # remove spouse name if possible to make elder easier to find..
      name = record[:name].gsub(/& \w+ /, "")
      # check against 2 lists of elders in case names don't match
      if !@elders.include?(name) and !@elders2.include?(name)
        next
      end
    end
    if record[:name].nil?
      next
    end
    
    record_values=[]
    @output_fields.each_key do |field|
      record_values.push(record[field])
    end
    line = CSV.generate_line(record_values)
    
    # print line to output
    puts line
  end
end

#
# Read data from input CSV file
#
def read_data(options={})
  orig_data = CSV.read(@filename, :skip_blanks => true)
  num_lines = orig_data.length
  if num_lines % @num_lines_per_linegroup == 0
    num_line_groups = num_lines / @num_lines_per_linegroup
  else
    raise "ERROR: Invalid number of lines in file!"
  end
  
#  puts "Num Lines: #{num_lines}"
#  puts "************************\n"
  
  # array for final data
  @final_data = []
  
  # go through each line group
  num_line_groups.times do |i|
    
    # init a temp hash
    temp_hashes = []
    @data_columns.each do |col|
      temp_hashes[col] = {}
    end
    
    # grab data per linegroup
    @num_lines_per_linegroup.times do |j|
      line = orig_data[i*@num_lines_per_linegroup + j]
      field_name = @input_data_rows[j]
      # parse columns within a line
      @data_columns.each do |col|
        data = line[col]
        temp_hashes[col][field_name] = data
       # puts "  #{line[col]}" if !line[col].nil?
      end
    end
    
    # push grabbed data onto master hash array
    temp_hashes.each do |record|
      if !record.nil?
        @final_data << record
      end
    end
    
  end  # per line groups
  
end

#
# remove no-name records
#
def clean_no_names(options={})
  @final_data.each_index do |i|
    if record[:name].nil?   # remove no-name records
      @final_data.delete_at(i)
      next
    end
  end
end

#
# clean up data from any issues
#
def clean_data(options={})
  
  @final_data.each_index do |i|
    record = @final_data[i]
    if record[:name].nil?   # remove no-name records
      @final_data.delete_at(i)
      next
    end
    if record[:address].nil? # remove no-address records, can't display!
      @last_log << "WARNING: Address Missing for #{record[:name]}!\n"
      @final_data.delete_at(i)
      next
    end
    if record[:elder].nil?
      @last_log << "WARNING: Elder Missing for #{record[:name]}!\n"
    end
    if !record[:extra].nil? # if extra data, then assume it is city/state/zip,
                            # merge :address and existing :city_state_zip,
                            # put :extra data into :city_state_zip
      
      # fix data
      @final_data[i][:address] = "#{record[:address]}, #{record[:city_state_zip]}"
      @final_data[i][:city_state_zip] = "#{record[:extra]}"
      @final_data[i][:extra] = nil
      
    end
    if record[:address] =~ /Apt/ and record[:address] !=~ /,/
      # insert comma for Apt to make it easier on google
      @final_data[i][:address] = "#{record[:address].gsub(/ Apt/, ", Apt")}"
#      @last_log << "NOTE: Funny address found for #{record[:name]}!\n"
#      @last_log << "       Address: #{record[:address]}!\n"
    end
    if !@elders.include?(record[:elder])  # if No elder found, then report
      @last_log << "WARNING: No Elder found for #{record[:name]}!\n"
      if record[:address] !=~ /\w*\s\w*/ and record[:extra].nil?
        # if this is the case, very likely this is the address
        # shift data by 1 record
        @final_data[i][:city_state_zip] = record[:address]
        @final_data[i][:address] = record[:elder]
        @final_data[i][:elder] = "No Elder"
      end
    end
    
    # finally filter for problematic addresses that don't seem to picked up by Google Maps Geocoding properly!
    if record[:address] =~ /FM 2222/
      @final_data[i][:address] = "#{record[:address].gsub(/FM 2222/, "RM 2222")}"
    end
    if record[:address] =~ /Mo Pac/
      @final_data[i][:address] = "#{record[:address].gsub(/Mo Pac/, "MoPac")}"
    end
    
  end
end

#
# assign congregation members to certain areas
# by zip code
#
def assign_areas(options={})
  options = {
            }.merge(options)

  # assign zip codes to areas
  @area_zips = {
     # Part of Austin
     :south => 0,            # south of the river
     :central => 0,          # near church, downtown
     :north => 0,            # north 183N not quite out of town yet
     :northwest => 0,        # cedar park, lake travis

     # Austin Outskirts
     :waynorth => 0,         # pflugerville, round rock, georgetown
     :east => 0,             # manor, elgin, hutto

     # Outside Austin
     :texas => 0,            # outside austin area but still in Texas
     :outside_texas => 0,    # outside Texas

     # Debug / Error checking
     :austin => 0,           # for error checking / debug
     :other => 0,            # for error checking / debug
  }

  @final_data.each_index do |i|
    record = @final_data[i]

    if record[:state] == 'TX'
      @final_data[i][:area] = :texas     # Folks outside any of the cities below but still in Texas
    
      if record[:city] == 'Austin'       # Folks in Austin
        @final_data[i][:area] = :austin  # Don't want any left in Austin :area, all should here be assigned to a zip code below!
        case @final_data[i][:zip]
        when '78749','78739','78735','78736','78737','78745','78748','78704','78744','78747','78742','78746','78738','78733'
          @final_data[i][:area] = :south
        when '78703','78705','78751','78701','78712','78751','78756','78702','78731','78752','78767'
          @final_data[i][:area] = :central
        when '78758','78757','78759','78753','78729','78708','78727'
          @final_data[i][:area] = :north
        when '78717','78726','78730','78732','78750'
          @final_data[i][:area] = :northwest
        when '78725','78724','78754','78723','78741'
          @final_data[i][:area] = :east
        when '78728'
          @final_data[i][:area] = :waynorth
        end
      # cities near to Austin
      elsif record[:city] == 'Del valle'
        @final_data[i][:area] = :east
      elsif record[:city] == 'Manchaca'
        @final_data[i][:area] = :south
      elsif record[:city] == 'Buda'
        @final_data[i][:area] = :south
      elsif record[:city] == 'Lockhart'
        @final_data[i][:area] = :south
      elsif record[:city] == 'Kyle'
        @final_data[i][:area] = :south
      elsif record[:city] == 'San marcos'
        @final_data[i][:area] = :south
      elsif record[:city] == 'Pflugerville'
        @final_data[i][:area] = :waynorth
      elsif record[:city] == 'Granger'
        @final_data[i][:area] = :waynorth
      elsif record[:city] == 'Round rock'
        @final_data[i][:area] = :waynorth
      elsif record[:city] == 'Georgetown'
        @final_data[i][:area] = :waynorth
      elsif record[:city] == 'Manor'
        @final_data[i][:area] = :east
      elsif record[:city] == 'Webberville'
        @final_data[i][:area] = :east
      elsif record[:city] == 'Elgin'
        @final_data[i][:area] = :east
      elsif record[:city] == 'Bastrop'
        @final_data[i][:area] = :east
      elsif record[:city] == 'Cedar park'
        @final_data[i][:area] = :northwest
      elsif record[:city] == 'Hutto'
        @final_data[i][:area] = :waynorth
      elsif record[:city] == 'Lake travis'
        @final_data[i][:area] = :northwest
      elsif record[:city] == 'Lago vista'
        @final_data[i][:area] = :northwest
      elsif record[:city] == 'Lakeway'
        @final_data[i][:area] = :northwest
      elsif record[:city] == 'Leander'
        @final_data[i][:area] = :northwest
      elsif record[:city] == 'Spicewood'
        @final_data[i][:area] = :northwest
      end

    else  # Folks outside of Texas (poor souls!)
      @final_data[i][:area] = :outside_texas
    end
  end
    
  
end

#
# add new separate fields for city, state, zip
#
def add_city_st_zip(options={})
  options = {
            }.merge(options)
  
  @final_data.each_index do |i|
    record = @final_data[i]
    
    # Use Indirizzo to parse address for me
    unless record[:city_state_zip].nil?
      address = Indirizzo::Address.new(record[:city_state_zip])
      @final_data[i][:city] = address.city[0].capitalize # for some reason returns as array
      @final_data[i][:state] = address.state
      @final_data[i][:zip] = address.zip
    end
    
  end
  
  
end

#
# Replace elders if necessary in database
# then corrects elders list itself,  if desired
#
def sub_elders(options={})
  options = { update_elder_master: true,
            }.merge(options)

  @final_data.each_index do |i|
    record = @final_data[i]
    if @elder_sub.key?(record[:elder])  # found matching elder
      @final_data[i][:elder] = @elder_sub[record[:elder]]  # modify elder in final database
    end
  end
  
  # optionally update elder master list
  if options[:update_elder_master]
    @elder_sub.each do |old_elder, new_elder|
      @elders.delete(old_elder)
      @elders << new_elder
    end                
  end
              
end


#
# quick way to report any log data captured
# for debugging
#
def data_report(options={})
  puts "\n\n"
  puts "**********************************\n"
  puts "**********************************"
  puts @last_log
end


# main basically
begin

  # interpret command line options
  @command_options = {}
  option_parser = OptionParser.new do |opts|
    opts.banner = "Usage: parse_church_data.rb database_filename.csv [options]"
    opts.separator ''
    
    opts.on('-h', '--help', 'Display help' ) { puts opts; exit }
    opts.on('-e', 'Output Elders Info only' ) { |e| @command_options[:elders_only] = true }
    opts.on('-d', 'Debug data output') { |d| @command_options[:debug] = true}
    opts.on('-z', 'Output Count by Zip ') { |z| @command_options[:zip] = true}
    opts.on('-a', 'Output By Congregation Area') { |a| @command_options[:area] = true}
    opts.on('-n', 'Omit Address Information') { |n| @command_options[:noaddr] = true}
  end
  
  option_parser.parse!
  
  # ERROR CHECKING of arguments
  if ARGV.length != 1
#    raise "ERROR: Invalid number of arguments"
    puts option_parser
    exit
  end
  @filename = ARGV[0]
#  puts "Filename: #{@filename}"

  if File.extname(@filename) != ".csv"
    raise "ERROR: #{@filename} not a CSV file!"
  end

  # init vars
  @last_log = ""
  
  # define CSV format of input and output files
  define_csv_format
  
  # read data from file
  read_data
  
  # clean data from issues
  clean_data
  
  # substitute for any recent elder changes
  sub_elders
  # add fields for city/state/zip
  add_city_st_zip
  # add areas assignment
  assign_areas
  
  # print data to display
  if @command_options[:debug]
    print_data
    data_report # mainly for debugging
  elsif @command_options[:zip]
    print_data(:by => :zip_code)
  elsif @command_options[:area]
    print_data(:by => :area)
  else # google map type output
    print_google_map_data( header: true )
  end
  
  
end
