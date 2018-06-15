
%% paths and tools

% add HMM-MAR toolbox
addpath(genpath('/Users/kosciessa/BrainHack/T_tools/HMM-MAR-master/'))

pn.dataDir = '/Users/kosciessa/BrainHack/B_data/10subjects_mat/';

info.sessionNames = {'AP_run-01'; 'AP_run-02'; 'PA_run-01'; 'PA_run-01'};

%% test image

load([pn.dataDir, 'subj_010001_ses-02_task-rest_acq-AP_run-01_M_BASC_scale064.mat'])
figure; imagesc(ts')

%% Adapt HMM-MAR code fMRI example (run_HMMMAR_2)

N = 10; % subjects
Q = 4; % sessions per subject
ttrial = 652; % time points
nregions = 93; % regions or voxels
Y = zeros(N*Q,1); % design matrix with conditions
X = randn(Q*N*ttrial,nregions); % all data concatenated
T = ttrial * ones(N*Q,1);  % length of data for each session
Tsubject = Q*ttrial * ones(N,1);  % length of data for each subject

% Functional connectivity profile for condition 1
FC_condition1 = randn(nregions); 
FC_condition1 = FC_condition1' * FC_condition1;
% % Functional connectivity profile for condition 2
% FC_condition2 = randn(nregions); 
% FC_condition2 = FC_condition2' * FC_condition2;
% Note that there is no difference in the mean activity between conditions

for j1 = 1:N
    for j2 = 1:Q
        t = (1:ttrial) + (j2-1)*ttrial + Q*(j1-1)*ttrial;
        n = (j1-1)*Q + j2;
        if rem(j2,2)
            Y(n,1) = 1;
            X(t,:) = X(t,:) * FC_condition1;
        else
            Y(n,2) = 1;
            X(t,:) = X(t,:) * FC_condition2;
        end
        for i = 1:nregions % do some smoothing
            X(t,i) = smooth(X(t,i));
        end
    end
end

options = struct();
e = explainedvar_PCA(X,T,options); % how much variance PCA explains on the data
pc1 = find(e>0.5,1); % get no. of PCA components to explain 50% of variance
pc2 = find(e>0.6,1); % get no. of PCA components to explain 60% of variance
pc3 = find(e>0.7,1); % get no. of PCA components to explain 70% of variance
pc4 = find(e>0.8,1); % get no. of PCA components to explain 80% of variance
pc5 = find(e>0.9,1); % get no. of PCA components to explain 90% of variance
pc6 = 0; % no pca
number_pca_components = [pc1 pc2 pc3 pc4 pc5 pc6];
number_states = 4:6;

template_configuration = struct();
template_configuration.order = 0; 
template_configuration.dropstates = 0; 
template_configuration.verbose = 0;
template_configuration.cyc = 50;
template_configuration.initcyc = 5;


i = 1; 
configurations = {}; % parameters of the HMM
% Gaussian distribution with  mean and full covariance
for k = number_states
    for pca_comp = number_pca_components
        configurations{i} = template_configuration;
        configurations{i}.K = k;
        configurations{i}.pca = pca_comp;
        configurations{i}.zeromean = 0; 
        configurations{i}.covtype = 'full';
        i = i + 1;
    end
end
% Gaussian distribution with just covariance
for k = number_states
    for pca_comp = number_pca_components
        configurations{i} = template_configuration;
        configurations{i}.K = k;
        configurations{i}.pca = pca_comp;
        configurations{i}.zeromean = 1; 
        configurations{i}.covtype = 'full';
        i = i + 1;
    end
end
% Gaussian distribution with just mean
for k = number_states
    for pca_comp = number_pca_components
        configurations{i} = template_configuration;
        configurations{i}.K = k;
        configurations{i}.pca = pca_comp;
        configurations{i}.zeromean = 0; 
        configurations{i}.covtype = 'uniquefull';
        i = i + 1;
    end
end
        
%% Run HMM and perform statistical testing on the HMM results vs the conditions

L = length(configurations);
Gamma = cell(length(configurations),1);
test_group = cell(length(configurations),1);

options_test = struct();
options_test.subjectlevel = 0;
options_test.Nperm = 1000;

for i = 1:length(configurations)
    [~,Gamma{i}] = hmmmar(X,T,configurations{i});
    t = hmmtest(Gamma{i},T,Tsubject,Y,options_test);
    test_group{i} = t.grouplevel; % only doing group-level testing
    disp([num2str(i) ' of ' num2str(L)])
end

%% Plot
    
L1 = length(number_pca_components) * length(number_states);
L2 = length(number_states);
L3 = length(number_pca_components);
titles = {'Gaussian','Gaussian no Mean','Gaussian no Cov'};

% fractional occupancies
figure(1);clf(1)
ii = 1; 
for i = 1:3
    for j = 1:L2
        subplot(3,L2,ii)
        K = number_states(j);
        M = zeros(L3,K);
        for l = 1:L3
            ind = (i-1)*L1 + (j-1)*L3 + l;
            M(l,:) = test_group{ind}.p_fractional_occupancy';
        end
        imagesc(M,[0 0.25]); colorbar
        title([titles{i} ' K=' num2str(K)])
        ylabel('PCA components');xlabel('States')
        ii = ii + 1; 
    end
end

% switching rate
figure(2);clf(2)
ii = 1; 
for i = 1:3
    subplot(1,3,i)
    M = zeros(L3,L2);
    for j = 1:L2
        for l = 1:L3
            ind = (i-1)*L1 + (j-1)*L2 + l;
            M(l,j) = test_group{ind}.p_switching_rate;
        end
    end
    imagesc(M,[0 0.25]); colorbar
    title([titles{i}])
    ylabel('PCA components');xlabel('No. States')
end
