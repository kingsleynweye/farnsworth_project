require 'open3'
require 'json'
require 'ice_nine'
require 'ice_nine/core_ext/object'
require 'deep_clone'
require 'fileutils'

METADATA_FILEPATH = '../miscellaneous/metadata.json'

def read_json(filepath)
    json = File.read("#{filepath}")
    metadata = JSON.parse(json)
    return metadata
end

def write_json(hash,filepath)
    directory = filepath.split(pattern='/')[0..-2].join('/')

    # create directory if it does not exist
    if directory.size > 0
        FileUtils.mkdir_p directory unless File.exists?(directory)
    else
    end

    File.open(filepath,"w") do |f|
        f.write(JSON.pretty_generate(hash))
    end
end

def build_workflows(metadata,workflow_template)
    workflow_template['seed_file'] = metadata['seed_filepath']
    workflow_template['weather_file'] = metadata['weather_filepath']
    window_to_wall_ratios = metadata['window_to_wall_ratios']
    projection_factors = metadata['projection_factors']
    combinations = window_to_wall_ratios.product(projection_factors)
    workflows = {}
    
    combinations.each do |combination|
        workflow = DeepClone.clone(workflow_template)
        wwr = combination[0]
        projection_factor = combination[1]
        workflow['steps'][0]['arguments']['wwr'] = wwr
        workflow['steps'][1]['arguments']['projection_factor'] = projection_factor
        workflows["wwr_#{wwr}_proj_#{projection_factor}"] = DeepClone.clone(workflow)
    end
    return workflows
end

def get_clean_env
    new_env = {}
    new_env['BUNDLER_ORIG_MANPATH'] = nil
    new_env['BUNDLER_ORIG_PATH'] = nil
    new_env['BUNDLER_VERSION'] = nil
    new_env['BUNDLE_BIN_PATH'] = nil
    new_env['RUBYLIB'] = nil
    new_env['RUBYOPT'] = nil
    new_env['GEM_PATH'] = nil
    new_env['GEM_HOME'] = nil
    new_env['BUNDLE_GEMFILE'] = nil
    new_env['BUNDLE_PATH'] = nil
    new_env['BUNDLE_WITHOUT'] = nil
    return new_env
end

def run()
    # Define directories and templates
    metadata = read_json(filepath=METADATA_FILEPATH)
    workflow_template_filepath = metadata['workflow_template_filepath']
    workflow_template = read_json(filepath=workflow_template_filepath)
    seed_name = metadata['seed_filepath'].split(pattern='/')[-1].split('.')[0]
    run_name = "#{seed_name}"
    runs_directory = "../runs/#{run_name}"

    # build workflows
    workflows = build_workflows(metadata=metadata,workflow_template=workflow_template)
    
    # write workflows
    workflow_filepaths = []
    workflows.each do |key, value|
        workflow_filepath = "#{runs_directory}/#{key}/#{seed_name}_#{key}.json"
        write_json(hash=value,filepath=workflow_filepath)
        workflow_filepaths << DeepClone.clone(workflow_filepath)
    end

    # Run simulations
    workflow_filepaths.each do |workflow_filepath|
        command = "openstudio --verbose run -w '#{workflow_filepath}'"
        stdout_str, stderr_str, status = Open3.capture3(get_clean_env,command)
    end
end

if $PROGRAM_NAME == __FILE__
    run()
end
