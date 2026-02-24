function data_generation()
% This function reads config.json and sequentially runs signalgen_module for all location1.csv, location2.csv, ... in the specified directory.

    % Path to config file
    script_dir = fileparts(mfilename('fullpath'));
    config_file = fullfile(script_dir, 'config.json');

    % Get location_seedfiles_path from config.json
    config = jsondecode(fileread(config_file));
    location_dir = fullfile(config.base_dir, 'location_seed');

    % Get all location*.csv files
    files = dir(fullfile(location_dir, 'location*.csv'));
    fprintf('--- %d location*.csv files found. ---\n', length(files));
    if isempty(files)
        error('No location*.csv files found in %s.', location_dir);
    end
    % Delete all files in the save_data_path directory before data generation
    save_full_path = fullfile(config.base_dir, 'tmp');
    save_data_path = fullfile(save_full_path, 'data');
    save_logs_path = fullfile(save_full_path, 'logs');

    % Delete all files in the save_data_path directory before data generation
    if exist(save_data_path, 'dir')
        files_to_delete = dir(fullfile(save_data_path, '*'));
        for k = 1:length(files_to_delete)
            fname = files_to_delete(k).name;
            % Skip '.' and '..'
            if ~strcmp(fname, '.') && ~strcmp(fname, '..')
                fpath = fullfile(save_data_path, fname);
                if isfile(fpath)
                    delete(fpath); % Delete file
                elseif isfolder(fpath)
                    % If there are subfolders, remove them recursively
                    rmdir(fpath, 's');
                end
            end
        end
        fprintf('All files in %s have been deleted before data generation.\n', save_data_path);
    else
        % If the directory does not exist, create it
        mkdir(save_data_path);
        fprintf('Directory %s did not exist and was created.\n', save_data_path);
    end

    % Delete all files in the save_logs_path directory before data generation
    if exist(save_logs_path, 'dir')
        files_to_delete = dir(fullfile(save_logs_path, '*'));
        for k = 1:length(files_to_delete)
            fname = files_to_delete(k).name;
            % Skip '.' and '..'
            if ~strcmp(fname, '.') && ~strcmp(fname, '..')
                fpath = fullfile(save_logs_path, fname);
                if isfile(fpath)
                    delete(fpath); % Delete file
                elseif isfolder(fpath)
                    % If there are subfolders, remove them recursively
                    rmdir(fpath, 's');
                end
            end
        end
        fprintf('All files in %s have been deleted before data generation.\n', save_logs_path);
    else
        % If the directory does not exist, create it
        mkdir(save_logs_path);
        fprintf('Directory %s did not exist and was created.\n', save_logs_path);
    end
    % Run signalgen_module for each CSV file
    % Initialize (delete all files and folders) in save_full_path directory before data generation
    if exist(save_full_path, 'dir')
        files_to_delete = dir(fullfile(save_full_path, '*'));
        for k = 1:length(files_to_delete)
            fname = files_to_delete(k).name;
            % Skip '.' and '..'
            if ~strcmp(fname, '.') && ~strcmp(fname, '..')
                fpath = fullfile(save_full_path, fname);
                if isfile(fpath)
                    delete(fpath); % Delete file
                elseif isfolder(fpath)
                    % Remove subfolders recursively
                    rmdir(fpath, 's');
                end
            end
        end
        fprintf('All files and folders in %s have been deleted before data generation.\n', save_full_path);
    else
        % If the directory does not exist, create it
        mkdir(save_full_path);
        fprintf('Directory %s did not exist and was created.\n', save_full_path);
    end

    % Copy config.json file to save_full_path
    config_file_src = config_file; % already absolute (script-relative)
    config_file_dst = fullfile(save_full_path, 'config.json');
    copyfile(config_file_src, config_file_dst);
    fprintf('config.json has been copied to %s.\n', save_full_path);

    % Copy location_seed directory into save_full_path for reproducibility
    location_dir_dst = fullfile(save_full_path, 'location_seed');
    if exist(location_dir_dst, 'dir')
        rmdir(location_dir_dst, 's');
    end
    copyfile(location_dir, location_dir_dst);
    fprintf('location_seed has been copied to %s.\n', location_dir_dst);

    % Re-scan location*.csv from the copied folder
    files = dir(fullfile(location_dir_dst, 'location*.csv'));
    fprintf('--- %d location*.csv files found (copied). ---\n', length(files));
    if isempty(files)
        error('No location*.csv files found in %s.', location_dir_dst);
    end

    for i = 1:length(files)
        location_csv = fullfile(location_dir_dst, files(i).name);
        fprintf('--- Processing %s ---\n', location_csv);
        % Use the copied config for the simulation run
        simulation_execution(config_file_dst, location_csv);
    end
end