% Make sure you load CobraToolbox first

load('recon22.mat');
changeCobraSolver('glpk','all');
model = recon22;
RPMImediumSimulation;

% Import the gene expression data
gxData = readtable('DATASET SenescenceGEM_ControlSen_geneExpressionData.txt');

% Separate
controlData    = gxData(:,[2,4]);
senescenceData = gxData(:,[2,5]);

% Rename
controlData.Properties.VariableNames{1} = 'gene';
controlData.Properties.VariableNames{2} = 'value';

senescenceData.Properties.VariableNames{1} = 'gene';
senescenceData.Properties.VariableNames{2} = 'value';

% Prepare iMAT input
[controlModel, controlOptions]       = prepDataForIMAT(modelRPMI, controlData);
[senescenceModel, senescenceOptions] = prepDataForIMAT(modelRPMI, senescenceData);

% Execute iMAT
controlModelIMAT    = createTissueSpecificModel(controlModel, controlOptions);
senescenceModelIMAT = createTissueSpecificModel(senescenceModel, senescenceOptions);

% SAVE THESE RESULTS FOR GOD'S SAKE

t = char(datetime(now,'ConvertFrom','datenum'));
t(regexp(t, '[: ]'))='-';

save(append('iMATresults-', t, '.mat'));