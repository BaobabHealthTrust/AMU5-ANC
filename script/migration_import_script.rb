require 'migrator'
require 'yaml'

Thread.abort_on_exception = true


# set the right number of mongrels in config/mongrel_cluster.yml
# (e.g. servers: 4) and the starting port (port: 8000)
def read_config
  config = YAML.load_file("config/migration.yml")
  @import_path = config["config"]["import_path"]
  @import_years = (config["config"]["import_years"]).split(",")
  @file_map_location = config["config"]["file_map_location"]
end

def initialize_variables

  print_time("initialization started")
  
  read_config
  
  @import_paths = ['/tmp/migrator-1', '/tmp/migrator-2', '/tmp/migrator-3',
                 '/tmp/migrator-4']
 
  @bart_urls = {
    'first' => 'admin:test@localhost:8000',
    'second' => 'admin:test@localhost:8001',
    'third' => 'admin:test@localhost:8002',
    'fourth' => 'admin:test@localhost:8003'
  }

  @importers = {
    'general_reception.csv'      => ReceptionImporter,
    'update_outcome.csv'         => OutcomeImporter,
    'give_drugs.csv'             => DispensationImporter,
    'art_visit.csv'              => ArtVisitImporter,
    'hiv_first_visit.csv'        => ArtInitialImporter,
    'date_of_art_initiation.csv' => ArtInitialImporter,
    'height_weight.csv'          => VitalsImporter,
    'hiv_staging.csv'            => HivStagingImporter,
    'hiv_reception.csv'          => ReceptionImporter
  }

  @ordered_files = ['general_reception.csv', 'hiv_reception.csv',
    'hiv_first_visit.csv', 'date_of_art_initiation.csv', 'height_weight.csv',
    'hiv_staging.csv', 'art_visit.csv', 'give_drugs.csv', 'update_outcome.csv'
  ]
  @quarters = ['first','second','third','fourth']
  
  @start_time = Time.now
  
  print_time("Initialization ended")
end

def import_encounters(afile, import_path,bart_url)
	puts "-----Starting #{import_path}/#{afile} importing - #{Time.now}"

  importer = @importers[afile].new(import_path, @file_map_location)
	importer.create_encounters(afile, @bart_urls[bart_url])

	puts "-----#{import_path}/#{afile} imported after #{Time.now - @start_time}s"
end

def print_time(message)
  @time = Time.now
  puts "-----#{message} at - #{@time} -----"
end

threads = []

print_time("import utility started")

initialize_variables

@import_years.each do |year|
  @quarters.each do |quarter|
      threads << Thread.new(quarter) do |path|
        current_dir = @import_path + "/#{year}/#{quarter}"
        @ordered_files.each do |file|
          import_encounters(file, current_dir,quarter) #added quarter to ensure that we get the right bart_url_import_path
        end
        puts '******#{Thread.name} ******************'
      end
  end
end
threads.each {|thread| thread.join}

print_time("----- Finished Import Script in #{Time.now - @start_time}s -----")

