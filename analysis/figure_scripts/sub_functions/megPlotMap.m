function [fH,ch] = megPlotMap(sensor_data,clims,fH,cm,ttl,data_hdr,cfg, varargin)

if notDefined('cm'),       cm = 'parula';    end  % colormap
if notDefined('ttl');      ttl = '';      end  % title string
if notDefined('fH'),       fH = gcf;      end
% if notDefined('data_hdr'), data_hdr = load('meg160_example_hdr.mat'); data_hdr = data_hdr.hdr; end
if notDefined('cfg'),      cfg = []; end

% Define other params
fs = 14; % font size
renderer = 'zbuffer';

%% Handle data header
% If more than 157, it is the uncombined Neuromag dataset, or less it is
% the combined Neuromag
if isempty(cfg)

    if length(sensor_data) <= 102 % Combined NeuroMag 204 channel MEG
        cfg.layout = 'neuromag306cmb'; % Use standard layout in Fieltrip
        cfg.layout = ft_prepare_layout(cfg);
    elseif length(sensor_data) <= 104 % Combined Yokogawa 208 channel MEG
        data_hdr = load('yokogawa_con_example_hdr.mat'); data_hdr = data_hdr.hdr;
        cfg.layout = ft_prepare_layout(cfg, data_hdr); % Create our own layout with Fieltrip function
    elseif length(sensor_data) <= 157 % Uncombined/standard Yokogawa 157 channel MEG
        data_hdr = load('meg160_example_hdr.mat'); data_hdr = data_hdr.hdr;
        cfg.layout = ft_prepare_layout(cfg, data_hdr); % Create our own layout with Fieltrip function
    elseif length(sensor_data) <= 204 % Uncombined NeuroMag 204 planar channel MEG
        cfg.layout = 'neuromag306planar';
        cfg.layout = ft_prepare_layout(cfg);
    elseif length(sensor_data) <= 208
        data_hdr = load('yokogawa_con_example_hdr.mat'); data_hdr = data_hdr.hdr;
        cfg.layout = ft_prepare_layout(cfg, data_hdr);
    else
        error(sprintf('(%s): Can''t find MEG layout configuration', mfilename))
    end
        
        
        
        
        
        
%         157 || length(sensor_data) > 157
%     
%     % Create layout
%     if length(sensor_data) > 157; cfg.layout = 'neuromag306planar';
%     elseif length(sensor_data) < 157; cfg.layout = 'neuromag306cmb'; end
%     
%     cfg.layout = ft_prepare_layout(cfg, 'neuromag360_sample_hdr_combined.mat'); 
%     
%     % Otherwise it is the Yokogawa dataset, which we might have to clip
% elseif length(sensor_data) >= 157
%     % Define plotting options
%     cfg.layout = ft_prepare_layout(cfg, data_hdr);
% end

% Check data
cfg.data = sensor_data';
cfg.data(isnan(cfg.data)) = nanmedian(sensor_data);
cfg.data(isinf(cfg.data)) = max(sensor_data);

%% Handle configuration
% Get channel X,Y positions
chanX  = cfg.layout.pos(1:length(sensor_data),1);
chanY  = cfg.layout.pos(1:length(sensor_data),2);

% Define options for plotting
opt = {'interpmethod','v4',... How to interpolate the data?
        'interplim','mask',... Mask the data such that it doesn't exceed the outline
        'gridscale',170,... How fine do you want the grid?
        'outline',cfg.layout.outline,... Create the lines of the head, nose and ears
        'shading','flat', ... How to interpolate the in the outline
        'mask',cfg.layout.mask,... 
        'datmask', []};

% check for input options (in paired parameter name / value)
if exist('varargin', 'var')
     for ii = 1:2:length(varargin)
         % paired parameter and value
         parname = varargin{ii};
         val     = varargin{ii+1};
         
         % check wehther this parameter exists in the defaults
         existingparnames = opt(1:2:end);
         tmp = strfind(existingparnames, parname);
         idx = find(cellfun(@(x) ~isempty(x), tmp));
         
         % if so, replace it; if not add it to the end of opt
         if ~isempty(idx), opt{idx+1} = val;
         else, opt{end+1} = parname; opt{end+1} = val; end
            
            
     end
end
%% Do the plotting
ft_plot_topo(chanX,chanY,cfg.data, opt{:});

% Make plot pretty
ft_plot_lay(cfg.layout,...
    'box','no',...
    'label','no',...
    'point','yes', ...
    'pointsymbol','.',...
    'pointcolor','k',...
    'pointsize',8, ...
    'colorbar', 'yes', ...
    'style','straight', ...
    'maplimits', 'maxmin')


colormap(cm);
if ~notDefined('clims'), set(gca, 'CLim', clims); end
set(fH, 'Renderer', renderer);
tH = title(ttl);
set(tH, 'FontSize', fs);
ch = colorbar;

end




