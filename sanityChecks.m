function tableRes = sanityChecks(model, testChoice, type)
% This function performs sanity checks
% Argument model        should be model as transformed by
%                       model = writeCbModel(model, 'xls', 'modelRPMI')
%          type         a string variable that can be used to create files
%                       with unique names (recommended use "Control" or
%                       "Senescent" 
%          testChoice   should be a matrix of 1 row and 15 boolean values,
%                       indicating which tests are to be provided
%                       the values are ordered in following pattern:
%                 (1)     fastLeakTest, 
%                 (2)     demandReactionMetabolLeakTest,
%                 (3)     energyFromWaterTest, 
%                 (4)     energyFromWaterAndOxygenTest,
%                 (5)     matterFromATPdemandReversTest,
%                 (6)     fluxThroughHMdemandTest,
%                 (7)     fluxThroughHCdemandTest,
%                 (8)     tooMuchATPdemandAerobicTest,
%                 (9)     metabolicObjectiveWithOpenSinksTest,
%                 (10)    metabolicObjectiveWithClosedSinks(lb)Test,
%                 (11)    ATPYieldTest,
%                 (12)    duplicatedReactionsTest,
%                 (13)    emptyColumnsTest,
%                 (14)    demandLB>=0Test,
%                 (15)    singleGeneDeletionTest,
%                 (16)    fluxConsistencyTest,

% arguments
%     model (1, 1) {mustBeStruct},
%     testChoice(1, 16) {mustBeBoolean}
% end

% Check whether the argument is valiad, and in it is not, make it valid
for num = 1:16
    if testChoice(1, num) ~= 1 || testChoice(1, num) ~= true
        testChoice(1, num) = false;
    end
end

changeCobraSolver ('glpk', 'all', 1);

%%

model.rxns(find(ismember(model.rxns,'ATPM')))={'DM_atp_c_'};
model.rxns(find(ismember(model.rxns,'ATPhyd')))={'DM_atp_c_'};
model.rxns(find(ismember(model.rxns,'DM_atp(c)')))={'DM_atp_c_'};
model.rxns(find(ismember(model.rxns,'EX_biomass_reaction')))={'biomass_reaction'};
model.rxns(find(ismember(model.rxns,'EX_biomass_maintenance')))={'biomass_maintenance'};
model.rxns(find(ismember(model.rxns,'EX_biomass_maintenance_noTrTr')))={'biomass_maintenance_noTrTr'};

%Set lower bound of the biomass reaction to 0.

model.lb(find(ismember(model.rxns,'biomass_reaction')))=0;
model.lb(find(ismember(model.rxns,'biomass_maintenance_noTrTr')))=0;
model.lb(find(ismember(model.rxns,'biomass_maintenance')))=0;

%Harmonize different use of brackets.

model.rxns = regexprep(model.rxns,'\(','\[');
model.rxns = regexprep(model.rxns,'\)','\]');
model.rxns = regexprep(model.rxns,'Ex_','EX_');
model.rxns = regexprep(model.rxns,'Sink_','sink_');
model.rxns = regexprep(model.rxns,'-','_');

%Define some parameters that we will need.

cnt = 1;
tol = 1e-6;

%Define the closed model. Here, we will set to zero the lower bounds of all reactions that represent exchange and siphon ('sink') reactions, or that contain only one entry in the column of the S matrix. The upper bound of those reactions is set to 1000 (i.e., infinity). Note that this overwrites any constraints on those reactions that may be present in a condition- and cell-type specific model.

modelClosed = model;
modelexchanges1 = strmatch('Ex_',modelClosed.rxns);
modelexchanges4 = strmatch('EX_',modelClosed.rxns);
modelexchanges2 = strmatch('DM_',modelClosed.rxns);
modelexchanges3 = strmatch('sink_',modelClosed.rxns);

selExc = (find( full((sum(abs(modelClosed.S)==1,1) ==1) & (sum(modelClosed.S~=0) == 1))))';


modelexchanges = unique([modelexchanges1;modelexchanges2;modelexchanges3;modelexchanges4;selExc]);
modelClosed.lb(find(ismember(modelClosed.rxns,modelClosed.rxns(modelexchanges))))=0;
modelClosed.ub(find(ismember(modelClosed.rxns,modelClosed.rxns(modelexchanges))))=1000;
modelClosedOri = modelClosed;

%% TESTS

if (testChoice(1, 1))
    modelClosed = modelClosedOri;
    [LeakRxns,modelTested,LeakRxnsFluxVector] = fastLeakTest(modelClosed,modelClosed.rxns(selExc),'false');
    TableChecks{cnt,1} = 'fastLeakTest 1';

    if length(LeakRxns)>0
        warning('model leaks metabolites!')
        TableChecks{cnt,2} = 'model leaks metabolites!';
    else
    TableChecks{cnt,2} = 'Leak free!';
    end

    cnt = cnt + 1;
end

if (testChoice(1,2))
    %Test if something leaks when demand reactions for each metabolite in the model are added. Note that this step is time consuming.

    modelClosed = modelClosedOri;
    [LeakRxnsDM,modelTestedDM,LeakRxnsFluxVectorDM] = fastLeakTest(modelClosed,modelClosed.rxns(selExc),'true');

    TableChecks{cnt,1} = 'fastLeakTest 2 - add demand reactions for each metabolite in the model';

    if length(LeakRxnsDM)>0
    TableChecks{cnt,2} = 'model leaks metabolites when demand reactions are added!';
    else
    TableChecks{cnt,2} = 'Leak free when demand reactions are added!';
    end

    cnt = cnt + 1;
    
end
    
if (testChoice(1, 3))
    %Test if the model produces energy from water!

    modelClosed = modelClosedOri;
    modelClosedATP = changeObjective(modelClosed,'DM_atp_c_');
    modelClosedATP = changeRxnBounds(modelClosedATP,'DM_atp_c_',0,'l');
    modelClosedATP = changeRxnBounds(modelClosedATP,'EX_h2o[e]',-1,'l');
    FBA3=optimizeCbModel(modelClosedATP);

    TableChecks{cnt,1} = 'Exchanges, sinks, and demands have lb = 0, except h2o';

    if abs(FBA3.f) > 1e-6
    TableChecks{cnt,2} = 'model produces energy from water!';
    else
    TableChecks{cnt,2} = 'model DOES NOT produce energy from water!';
    end

    cnt = cnt + 1;
end
if (testChoice(1, 4))
    %Test if the model produces energy from water and oxygen!

    modelClosed = modelClosedOri;
    modelClosedATP = changeObjective(modelClosed,'DM_atp_c_');
    modelClosedATP = changeRxnBounds(modelClosedATP,'DM_atp_c_',0,'l');
    modelClosedATP = changeRxnBounds(modelClosedATP,'EX_h2o[e]',-1,'l');
    modelClosedATP = changeRxnBounds(modelClosedATP,'EX_o2[e]',-1,'l');

    FBA6=optimizeCbModel(modelClosedATP);
    TableChecks{cnt,1} = 'Exchanges, sinks, and demands have lb = 0, except h2o and o2';

    if abs(FBA6.f) > 1e-6
    TableChecks{cnt,2} = 'model produces energy from water and oxygen!';
    else
    TableChecks{cnt,2} = 'model DOES NOT produce energy from water and oxygen!';
    end

    cnt = cnt + 1;
end
if (testChoice(1, 5))
    %Test if the model produces matter when atp demand is reversed!

    modelClosed = modelClosedOri;
    modelClosed = changeObjective(modelClosed,'DM_atp_c_');
    modelClosed.lb(find(ismember(modelClosed.rxns,'DM_atp_c_'))) = -1000;

    FBA = optimizeCbModel(modelClosed);
    TableChecks{cnt,1} = 'Exchanges, sinks, and demands have lb = 0, allow DM_atp_c_ to be reversible';

    if abs(FBA.f) > 1e-6
    TableChecks{cnt,2} = 'model produces matter when atp demand is reversed!';
    else
    TableChecks{cnt,2} = 'model DOES NOT produce matter when atp demand is reversed!';
    end

    cnt = cnt + 1;
end
if (testChoice(1, 6))
    %Test if the model has flux through h[m] demand !

    modelClosed = modelClosedOri;
    modelClosed = addDemandReaction(modelClosed,'h[m]');
    modelClosed = changeObjective(modelClosed,'DM_h[m]');
    modelClosed.ub(find(ismember(modelClosed.rxns,'DM_h[m]'))) = 1000;

    FBA = optimizeCbModel(modelClosed,'max');
    TableChecks{cnt,1} = 'Exchanges, sinks, and demands have lb = 0, test flux through DM_h[m] (max)';

    if abs(FBA.f) > 1e-6
    TableChecks{cnt,2} = 'model has flux through h[m] demand (max)!';
    else
    TableChecks{cnt,2} = 'model has NO flux through h[m] demand (max)!';
    end

    cnt = cnt + 1;
end
if (testChoice(1, 7))
    %Test if the model has flux through h[c] demand !

    modelClosed = modelClosedOri;
    modelClosed = addDemandReaction(modelClosed,'h[c]');
    modelClosed = changeObjective(modelClosed,'DM_h[c]');
    modelClosed.ub(find(ismember(modelClosed.rxns,'DM_h[c]'))) = 1000;

    FBA = optimizeCbModel(modelClosed,'max');
    TableChecks{cnt,1} = 'Exchanges, sinks, and demands have lb = 0, test flux through DM_h[c] (max)';

    if abs(FBA.f) > 1e-6
    TableChecks{cnt,2} = 'model has flux through h[c] demand (max)!';
    else
    TableChecks{cnt,2} = 'model has NO flux through h[c] demand (max)!';
    end

    cnt = cnt + 1;
end
if (testChoice(1, 8))
    %Test if the model produces too much atp demand from glucose under aerobic condition. Also consider using the tutorial testmodelATPYield to test if the correct ATP yield from different carbon sources can be realized by the model.

    modelClosed = modelClosedOri;
    modelClosed = changeObjective(modelClosed,'DM_atp_c_');
    modelClosed.lb(find(ismember(modelClosed.rxns,'EX_o2[e]'))) = -1000;
    modelClosed.lb(find(ismember(modelClosed.rxns,'EX_h2o[e]'))) = -1000;
    modelClosed.ub(find(ismember(modelClosed.rxns,'EX_h2o[e]'))) = 1000;
    modelClosed.ub(find(ismember(modelClosed.rxns,'EX_co2[e]'))) = 1000;

    FBAOri = optimizeCbModel(modelClosed,'max');
    TableChecks{cnt,1} = 'ATP yield ';

    if abs(FBAOri.f) > 31 % this is the theoretical value
    TableChecks{cnt,2} = 'model produces too much atp demand from glc!';
    else
    TableChecks{cnt,2} ='model DOES NOT produce too much atp demand from glc!';
    end

    cnt = cnt + 1;
end
if (testChoice(1, 9))
    %Test metabolic objective functions with open sinks. Note this step is time consuming and may only work reliably on Recon 3D derived models due to different usage of abbreviations.

    TableChecks{cnt,1} = 'Test metabolic objective functions with open sinks';

    [TestSolution,TestSolutionNameOpenSinks, TestedRxnsSinks, PercSinks] = test4HumanFctExt(model,'all');
    TableChecks{cnt,2} = strcat('Done. See variable TestSolutionNameOpenSinks for results. The model passes ', num2str(length(find(abs(TestSolution)>tol))),' out of ', num2str(length(TestSolution)), 'tests');
   
    cnt = cnt + 1;
end 
if (testChoice(1, 10))
    %Test metabolic objective functions with closed sinks (lb). Note this step is time consuming and may only work reliably on Recon 3D derived models due to different usage of abbreviations.

    TableChecks{cnt,1} = 'Test metabolic objective functions with closed sinks (lb)';

    [TestSolution,TestSolutionNameClosedSinks, TestedRxnsClosedSinks, PercClosedSinks] = test4HumanFctExt(model,'all',0);
    TableChecks{cnt,2} = strcat('Done. See variable TestSolutionNameClosedSinks for results. The model passes ', num2str(length(find(abs(TestSolution)>tol))),' out of ', num2str(length(TestSolution)), 'tests');
    
    cnt = cnt + 1;
end
if (testChoice(1, 11))
    % Compute ATP yield. This test is identical to the material covered in the tutorial testmodelATPYield.

    TableChecks{cnt,1} = 'Compute ATP yield';

    [Table_csources, TestedRxns, Perc] = testATPYieldFromCsources(model);
    TableChecks{cnt,2} = 'Done. See variable Table_csources for results.';
    
    cnt = cnt + 1;
end
if (testChoice(1, 12))
    %Check for duplicated reactions in the model.

    TableChecks{cnt,1} = 'Check duplicated reactions';
    method='FR';
    removeFlag=0;
    [modelOut,removedRxnInd, keptRxnInd] = checkDuplicateRxn(model,method,removeFlag,0);

    if isempty(removedRxnInd)
    TableChecks{cnt,2} = 'No duplicated reactions in model.';
    else
    TableChecks{cnt,2} = 'Duplicated reactions in model.';
    end

    cnt = cnt + 1;
end
if (testChoice(1, 13))
    %Check empty columns in 'model.rxnGeneMat'.

    TableChecks{cnt,1} = 'Check empty columns in rxnGeneMat';
    E = find(sum(model.rxnGeneMat)==0);

    if isempty(E)
    TableChecks{cnt,2} = 'No empty columns in rxnGeneMat.';
    else
    TableChecks{cnt,2} = 'Empty columns in rxnGeneMat.';
    end

    cnt = cnt + 1;
end
if (testChoice(1, 14))
    %Check that demand reactions have a lb >= 0.

    TableChecks{cnt,1} = 'Check that demand reactions have a lb >= 0';
    DMlb = find(model.lb(strmatch('DM_',model.rxns))<0);

    if isempty(DMlb)
    TableChecks{cnt,2} = 'No demand reaction can have flux in backward direction.';
    else
    TableChecks{cnt,2} = 'Demand reaction can have flux in backward direction.';
    end

    cnt = cnt + 1;
end
    
if (testChoice(1, 15))
    %Check whether singleGeneDeletion runs smoothly.

    TableChecks{cnt,1} = 'Check whether singleGeneDeletion runs smoothly';

    try
    [grRatio,grRateKO,grRateWT,hasEffect,delRxns,fluxSolution] = singleGeneDeletion(model);
    TableChecks{cnt,2} = 'singleGeneDeletion finished without problems.';
    catch
    TableChecks{cnt,2} = 'There are problems with singleGeneDeletion.';
    end

    cnt = cnt + 1;
end
if (testChoice(1, 16))
    % Check for flux consistency.

    TableChecks{cnt,1} = 'Check for flux consistency';
    param.epsilon=1e-4;
    param.modeFlag=0;

    %param.method='null_fastcc';

    param.method='fastcc';
    printLevel = 1;
    [fluxConsistentMetBool,fluxConsistentRxnBool,fluxInConsistentMetBool,fluxInConsistentRxnBool,model] = findFluxConsistentSubset(model,param,printLevel);

    if isempty(find(fluxInConsistentRxnBool))
    TableChecks{cnt,2} = 'model is flux consistent.';
    else
    TableChecks{cnt,2} = 'model is NOT flux consistent';
    end

    cnt = cnt + 1;
end
if (testChoice == false)
    disp ('no tests were specified')
    
end
    


%% DISPLAY AND SAVE RESULTS

%Display all results.

tableRes = TableChecks;

%Save all results.

t = char(datetime(now,'ConvertFrom','datenum'));
t = t(~isspace(t));
t(regexp(t, '[:]'))='-';
resultsFileName = append('TestResults', type, t);
save(strcat(resultsFileName,'.mat'));

end