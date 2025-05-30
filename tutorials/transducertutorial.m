% =========================================================================
% k-Wave transducer tutorial
% =========================================================================
clearvars;
close all;
DATA_CAST = 'gpuArray-single';
USE_STATISTICS = true;   % ★ ここを追加（または true に切替）
% -------------------------------------------------------------------------
% 1) 設定ファイルの読み込み
% -------------------------------------------------------------------------
config = jsondecode(fileread('config_tutorial.json'));

% -------------------------------------------------------------------------
% 2) シミュレーション用グリッドの定義
% -------------------------------------------------------------------------
kgrid = kWaveGrid(config.grid.Nx, config.grid.dx, config.grid.Ny, config.grid.dy,config.grid.Nz, config.grid.dz);
save_path = config.save_path;

% -------------------------------------------------------------------------
% 3) 媒質パラメータ
% -------------------------------------------------------------------------
medium.sound_speed = config.medium.water.sound_speed;
medium.density = config.medium.water.density;
kgrid.makeTime(medium.sound_speed, 0.05, config.simulation.t_end);
% -------------------------------------------------------------------------
% 4) トランスデューサーの設定
% -------------------------------------------------------------------------
transducer.number_elements = 72;    % total number of transducer elements
transducer.element_width = 1;       % width of each element [grid points/voxels]
transducer.element_length = 12;     % length of each element [grid points/voxels]
transducer.element_spacing = 0;     % spacing (kerf  width) between the elements [grid points/voxels]
transducer.radius = inf;            % radius of curvature of the transducer [m]
transducer_width = transducer.number_elements * transducer.element_width ...
    + (transducer.number_elements - 1) * transducer.element_spacing;
transducer.position = round([1, config.grid.Ny/4 - transducer_width/8, config.grid.Nz/2 - transducer.element_length/2]);
transducer.sound_speed = config.medium.water.sound_speed;
transducer.focus_distance = 25e-3;
transducer.elevation_focus_distance = 19e-3;
transducer.steering_angle = 0;
transducer.transmit_apodization = 'Rectangular';
transducer.receive_apodization = 'Rectangular';
transducer.active_elements = zeros(transducer.number_elements, 1);
transducer.active_elements(21:52) = 1;

transducer_trans.number_elements = 72;    % total number of transducer elements
transducer_trans.element_width = 1;       % width of each element [grid points/voxels]
transducer_trans.element_length = 12;     % length of each element [grid points/voxels]
transducer_trans.element_spacing = 0;     % spacing (kerf  width) between the elements [grid points/voxels]
transducer_trans.radius = inf;            % radius of curvature of the transducer [m]
transducer_width = transducer.number_elements * transducer.element_width ...
    + (transducer.number_elements - 1) * transducer.element_spacing;
transducer_trans.position = round([config.grid.Nx-5, config.grid.Ny/4 - transducer_width/8, config.grid.Nz/2 - transducer.element_length/2]);
transducer_trans.sound_speed = config.medium.water.sound_speed;
transducer_trans.focus_distance = 25e-3;
transducer_trans.elevation_focus_distance = 19e-3;
transducer_trans.steering_angle = 0;
transducer_trans.transmit_apodization = 'Rectangular';
transducer_trans.receive_apodization = 'Rectangular';
transducer_trans.active_elements = zeros(transducer.number_elements, 1);
transducer_trans.active_elements(21:52) = 1;
% -------------------------------------------------------------------------
% 5) ソース波形の設定
% -------------------------------------------------------------------------
source_strength = 1e6;          % [Pa]
tone_burst_freq = 4e6;        % [Hz]
tone_burst_cycles = 4;
source_signal = zeros(size(kgrid.t_array));
T_prf = 1 / config.source.prf;
t_array = kgrid.t_array;

for n = 0:config.source.max_n
    t_start = n * T_prf;
    t_end = t_start + config.source.pulse_length;
    
    if t_start > kgrid.t_array(end)
        break;
    end
    
    idx_on = (t_array >= t_start) & (t_array < t_end);
    source_signal(idx_on) = config.source.magnitude * sin(2*pi * config.source.frequency * (t_array(idx_on) - t_start));
end
transducer.input_signal = source_signal;

% -------------------------------------------------------------------------
% 6) トランスデューサーの初期化
% -------------------------------------------------------------------------
transducer = kWaveTransducer(kgrid, transducer);
transducer_trans = kWaveTransducer(kgrid, transducer_trans);
% -------------------------------------------------------------------------
% 7) センサーの設定
% -------------------------------------------------------------------------
sensor.mask = zeros(config.grid.Nx, config.grid.Ny, config.grid.Ny);
sensor_x = config.grid.Nx/2 + config.sensor.x_offset;
sensor_y = config.grid.Ny/2 + config.sensor.y_offset;

% stream the data to disk in blocks of 100 if storing the complete time
% history 
%if ~USE_STATISTICS
%    input_args = [input_args {'StreamToDisk', 100}];
%end
input_args = {'DisplayMask', transducer.active_elements_mask, ...
    'RecordMovie', true, ...
    'MovieName', fullfile(save_path, 'transducer_tutorial.avi'), ...
    'DataCast', DATA_CAST, 'PlotScale', [-1/4, 1/4] * source_strength};
sensor.record = {'p'};

% run the simulation
sensor_data = kspaceFirstOrder3DG(kgrid, medium, transducer, transducer_trans, input_args{:});

% =========================================================================
% COMPUTE THE BEAM PATTERN USING SIMULATION STATISTICS
% =========================================================================
voxelPlot(double(transducer.active_elements_mask |transducer_trans.active_elements_mask ));
view(127, 18);
saveas(gcf, fullfile(save_path, 'trans_config_3d_tut.png'));
if USE_STATISTICS
    
    % reshape the returned rms and max fields to their original position
    sensor_data.p_rms = reshape(sensor_data.p_rms, [Nx, Nj]);
    sensor_data.p_max = reshape(sensor_data.p_max, [Nx, Nj]);
    
    % plot the beam pattern using the pressure maximum
    figure;
    imagesc(j_vec * 1e3, (kgrid.x_vec - min(kgrid.x_vec(:))) * 1e3, sensor_data.p_max * 1e-6);
    xlabel([j_label '-position [mm]']);
    ylabel('x-position [mm]');
    title('Total Beam Pattern Using Maximum Of Recorded Pressure');
    colormap(jet(256));
    c = colorbar;
    ylabel(c, 'Pressure [MPa]');
    axis image;
    
    % plot the beam pattern using the pressure rms
    figure;
    plot(kgrid.t_array*1e3, sensor_data.p(1, :));
    xlabel('Time [ms]');
    ylabel('Pressure [Pa]');
    title('Pressure at the sensor');
    saveas(gcf, fullfile(save_path, 'sensor_transducer_tutorial.png')); 
end

% kspaceFirstOrder2D実行後にGPU配列をCPUに集約
sensor_data_cpu = structfun(@gather, sensor_data, 'UniformOutput', false);

% v7.3 形式で.matファイル保存
save(fullfile(save_path, 'sensor_data_transducer_tutorial.mat'), 'sensor_data_cpu', '-v7.3'); 