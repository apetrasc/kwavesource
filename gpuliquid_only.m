% =========================================================================
% k-Wave liquid -only tutorial (GPU,no movie) 
% =========================================================================
clearvars;
close all;
DATA_CAST = 'gpuArray-single';
% -------------------------------------------------------------------------
% 1) 設定ファイルの読み込み
% -------------------------------------------------------------------------
config = jsondecode(fileread('config.json'));
USE_STATISTICS = true;
% -------------------------------------------------------------------------
% 2) シミュレーション用グリッドの定義
% -------------------------------------------------------------------------
Nx=config.grid.Nx; Ny=config.grid.Ny; Nz=config.grid.Nz;
dx=config.grid.dx; dy=config.grid.dy; dz=config.grid.dz;
kgrid = kWaveGrid(Nx, dx, Ny, dy, Nz, dz);
save_path = config.save_path;

% -------------------------------------------------------------------------
% 3) 媒質パラメータ
% -------------------------------------------------------------------------

medium.sound_speed = config.medium.water.sound_speed * ones(Nx,Ny,Nz,'single');
medium.density     = config.medium.water.density     * ones(Nx,Ny,Nz,'single');
medium.alpha_coeff = config.medium.water.alpha_coeff * ones(Nx,Ny,Nz,'single');
medium.alpha_power = config.medium.water.alpha_power;
medium.BonA = 6;
kgrid.makeTime(medium.sound_speed, 0.05, config.simulation.t_end);
% -------------------------------------------------------------------------
% 4) トランスデューサーの設定
% -------------------------------------------------------------------------
transducer.number_elements = 90;    % total number of transducer elements
transducer.element_width = 1;       % width of each element [grid points/voxels]
transducer.element_length = 12;     % length of each element [grid points/voxels]
transducer.element_spacing = 0;     % spacing (kerf  width) between the elements [grid points/voxels]
transducer.radius = inf;            % radius of curvature of the transducer [m]
transducer_width = transducer.number_elements * transducer.element_width ...
    + (transducer.number_elements - 1) * transducer.element_spacing;

transducer.position = round([55, Ny/2 - transducer_width/2, Nz/2 - transducer.element_length/2]);
transducer.sound_speed = config.medium.water.sound_speed;
transducer.focus_distance = 25e-3;
transducer.elevation_focus_distance = 19e-3;
transducer.steering_angle = 0;
transducer.transmit_apodization = 'Rectangular';
transducer.receive_apodization = 'Rectangular';
transducer.active_elements = zeros(transducer.number_elements, 1);
transducer.active_elements(21:52) = 1;

transducer3.number_elements = 90;    % total number of transducer elements
transducer3.element_width = 1;       % width of each element [grid points/voxels]
transducer3.element_length = 12;     % length of each element [grid points/voxels]
transducer3.element_spacing = 0;     % spacing (kerf  width) between the elements [grid points/voxels]
transducer3.radius = inf;            % radius of curvature of the transducer [m]
transducer_width = transducer.number_elements * transducer.element_width ...
    + (transducer.number_elements - 1) * transducer.element_spacing;
transducer3.position = round([Nx-55, Ny/2 - transducer_width/2+1, Nz/2 - transducer.element_length/2+1]);
transducer3.sound_speed = config.medium.water.sound_speed;
transducer3.focus_distance = 25e-3;
transducer3.elevation_focus_distance = 19e-3;
transducer3.steering_angle = 0;
transducer3.transmit_apodization = 'Rectangular';
transducer3.receive_apodization = 'Rectangular';
transducer3.active_elements = zeros(transducer3.number_elements, 1);
transducer3.active_elements(21:52) = 1;

% ビニール円環のマスクを作成 - サイズを調整
cx = Nx/2;            % X 方向の中心
cy = Ny/2;            % Y 方向の中心

% 外径・内径をグリッドポイント数に変換（mmからmに変換してから計算）
outer_r_mm = 16;  % 外径 [mm]
inner_r_mm = 13;  % 内径 [mm]
outer_r = round((outer_r_mm * 1e-3) / dx);  % 外径をグリッドポイント数に変換
inner_r = round((inner_r_mm * 1e-3) / dx);  % 内径をグリッドポイント数に変換

% 2次元の円環マスクを作成
[Xg, Yg] = ndgrid(1:Nx, 1:Ny);
ring2d = sqrt((Xg-cx).^2 + (Yg-cy).^2);
ringMask = (ring2d <= outer_r) & (ring2d >= inner_r);   % Nx×Ny logical

pipe_mask = repmat(ringMask, [1 1 Nz]);   % Nx×Ny×Nz   
medium.sound_speed(pipe_mask == 1) = config.medium.vinyl.sound_speed;
medium.density(pipe_mask == 1) = config.medium.vinyl.density;
medium.alpha_coeff(pipe_mask) = config.medium.vinyl.alpha_coeff;
%medium.alpha_power(pipe_mask) = config.medium.vinyl.alpha_power;

% -------------------------------------------------------------------------
% 5) ソース波形の設定
% -------------------------------------------------------------------------

base_signal = toneBurst(1/kgrid.dt, config.source.tone_burst_freq, config.source.tone_burst_cycles);
base_signal = (config.source.source_strength ./ (config.medium.water.sound_speed * config.medium.water.density)) .* base_signal;

source_signal = zeros(size(kgrid.t_array));
T_prf = 1 / config.source.prf;  
burst_length = length(base_signal);
dt = kgrid.dt;
burst_time = burst_length * dt;

% Generate source signal with multiple pulses
for n = 0:config.source.max_n
    t_start_idx = round(n * T_prf / dt) + 1;
    if t_start_idx > length(kgrid.t_array)
        break;
    end
    
    end_idx = min(t_start_idx + burst_length - 1, length(source_signal));
    signal_length = end_idx - t_start_idx + 1;
    source_signal(t_start_idx:end_idx) = base_signal(1:signal_length);
end
transducer.input_signal = source_signal;


% -------------------------------------------------------------------------
% 6) トランスデューサーの初期化
% -------------------------------------------------------------------------
transducer = kWaveTransducer(kgrid, transducer);
transducer3 = kWaveTransducer(kgrid, transducer3);
%transducer.properties;
% -------------------------------------------------------------------------
% 7) センサーの設定
% -------------------------------------------------------------------------
sensor.mask = zeros(Nx, Ny, Ny);
sensor_x = Nx/2 + config.sensor.x_offset;
sensor_y = Ny/2 + config.sensor.y_offset;

% stream the data to disk in blocks of 100 if storing the complete time
% history 
%if ~USE_STATISTICS
%    input_args = [input_args {'StreamToDisk', 100}];
%end
%display_mask = transducer.active_elements_mask | transducer3.active_elements_mask | pipe_mask | glass_mask;
display_mask = transducer.active_elements_mask | transducer3.active_elements_mask | pipe_mask;
input_args = {'DisplayMask', display_mask, ...
    'DataCast', DATA_CAST, 'PlotScale', [-1/4, 1/4] * config.source.source_strength};
sensor.record = {'p','p_max'};

% run the simulation
sensor_data = kspaceFirstOrder3DG(kgrid, medium, transducer, transducer, input_args{:});
%save(fullfile(save_path, 'liquid_only_ref.mat'), ...
%    'sensor_data', ...           % 送信用トランスデューサーで記録したデータ
%   'kgrid', ...                 % グリッド情報
%   'kgrid.t_array', ...               % 時間配列
%    'source_signal', ...         % 入力信号
%    '-v7.3');                    % 大きなデータセット用に-v7.3フォーマットを使用
% =========================================================================
% COMPUTE THE BEAM PATTERN USING SIMULATION STATISTICS
% =========================================================================

scan_line = transducer.scan_line(sensor_data);
figure(1);
plot(kgrid.t_array * 1e6, scan_line * 1e-6, 'b-');
xlabel('Time [\mus]');
ylabel('Pressure [MPa]');
ylim([-1 1]);
title('Signal from Transducer reflection');
grid on;
saveas(gcf, fullfile(save_path, 'signal_liquid_only_reflection.png'));
% Method 3: Alternative visualization using isosurface
% % Plot the source signal
figure(2);
plot(kgrid.t_array * 1e6, source_signal * 1e-6, 'r-');
xlabel('Time [\mus]');
ylabel('Pressure [MPa]');
title('Source Signal');
grid on;
saveas(gcf, fullfile(save_path, 'source_signal.png'));
figure(3);
% Convert logical masks to double for visualization
transducer_mask_double = double(transducer.active_elements_mask);
transducer3_mask_double = double(transducer3.active_elements_mask);
pipe_mask_double = double(pipe_mask);

% Create separate masks for visualization
%glass_transducer_mask = glass_mask_double + transducer_mask_double + transducer3_mask_double;
transducer_mask = transducer_mask_double + transducer3_mask_double;
pipe_only_mask = pipe_mask_double;

% Create isosurface plots
% Glass and transducers (solid)
p1 = patch(isosurface(transducer_mask, 0.5));
isonormals(transducer_mask, p1);
set(p1, 'FaceColor', 'blue', 'EdgeColor', 'none', 'FaceAlpha', 0.8);

% Pipe (transparent)
p2 = patch(isosurface(pipe_only_mask, 0.5));
isonormals(pipe_only_mask, p2);
set(p2, 'FaceColor', 'green', 'EdgeColor', 'none', 'FaceAlpha', 0.2);

% Set up the figure
daspect([1 1 1]);
view(80, 30);
camlight;
lighting gouraud;
axis([1 size(transducer_mask,1) 1 size(transducer_mask,2) 1 size(transducer_mask,3)]);
title('Liquid only experimental settings');
saveas(gcf, fullfile(save_path, 'liquid_only.png'));

figure;
stackedPlot(kgrid.t_array * 1e6, sensor_data);
xlabel('Time [\mus]');
ylabel('Transducer Element');
title('Recorded Pressure');
scaleFig(1, 1.5);
saveas(gcf, fullfile(save_path, 'signal_liquid_only_Transducer_Element.png'));