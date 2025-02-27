function [model_original] = SpecificModelfillGaps(model_original,strains,inputpath)
%% This function is to find gaps and identify crucial rxns for biomass precursors synthethis
% this function has been divided into several steps
% step 1: identify the crucial rxns missing for growth
% step 2: to check for each biomass composition
% step 2b: fix the grRule caused by the draft model
% step 3: fix alternative pwys gap
% step 4: fix oxidative repiration chain adding those reactions back if not
% step 5: automatic gap-filling appraoch
% total input: download modelRelated from figshare
%              StrainData.strains;  '../modelRelated/StrainData.mat'
%              model_original in cobra format  '../modelRelated/panModel.mat'
%              inputpath is the model path '../modelRelated/ssGEMs'

% ranMatrix
% should contains a filrfolder for modelRelated 
mkdir('../modelRelated') % if not create one
%% Step 1 analyse whic biomass precursors that cannot be produced (input: panmodel in cobra format; StrainData.strains;)
%panmodel = ravenCobraWrapper(model_original); %change to raven format

%load('StrainData.mat')
cd otherchanges/
%strains = StrianData.strains;
%inputpath = '/Users/feiranl/Documents/GitHub/Yeast-Species-GEMs/Reconstruction_script/ModelFiles/mat';
[proMarix,rxnMatrix,mets_test] = getprecursorMatrixCobra(model_original,strains,inputpath); % all precursors and check proMatrix
% find rxn related to production of that met % ranMatrix stands for rxn
% existence information in each strain, all stores information whether the
% products can be produced or not
% we sort them into three groups: can produce this met and other mets
% tested

mapping = [];
rxn = [];
for i = 1:length(proMarix(1,:))
    i
    % group 1 can produce this met
    group1 = strains(find(proMarix(:,i)));
    group1_comrxn = rxnMatrix(find(proMarix(:,i)),:);
    group1_comrxn = model_original.rxns(all(group1_comrxn,1));
    
    % group 2 cannot produce this met & 90% other mets tested can be
    % produced
    group2 = strains(find(~proMarix(:,i)));
    group2_comrxn = rxnMatrix(find(~proMarix(:,i)),:);
    group2_comrxn = model_original.rxns(all(group2_comrxn,1));
    
    rxn_test = setdiff(group1_comrxn,group2_comrxn);
    
    model_out = model_original;
    for j = 1:length(rxn_test)
        disp([num2str(j),'/',num2str(length(rxn_test))])
        model = model_out;
        model = removeRxns(model, rxn_test{j});
        [missingMets, presentMets] = PrecursorCheck(model,false,false,[],mets_test(i));
        %sol.f
        if isempty(presentMets)
            rxn = [rxn;rxn_test(j),mets_test(i)];
        else
            model_out = model;
        end
    end
end


[~,rxn_index] = ismember(rxn(:,1),model_original.rxns);
% Change back to cobra format, in order to get ECnumber,MNXids.
rxn(:,4) = model_original.rxnMetaNetXID(rxn_index);
rxn(:,3) = mapIDsViaMNXref('rxns',rxn(:,4),'MetaNetX','KEGG');
rxn(:,2) = mapIDsViaMNXref('rxns',rxn(:,4),'MetaNetX','MetaCyc');
%find the unique list for rxns
[~,idx]=unique(strcat(rxn(:,1),rxn(:,2),rxn(:,3),rxn(:,4)));
rxn=rxn(idx,:);

clearvars -EXCEPT rxn panmodel model_original strains filefolder inputpath outputpath
% delete rxns without keggID or Metacyc ID
temp = cellfun(@(x)~isempty(x(:)),rxn);
idx = any(temp==0,2);
rxn_onlyonetype = rxn(idx,:);% with only keggID or metacycID
temp = cellfun(@(x)~isempty(x(:)),rxn_onlyonetype);
rxn_onlyonetype(~temp) = {'NA'};

rxn = rxn(~idx,:);
% This step is to find whether those rxns we found in last step exist in draft model or not
outputpath = inputpath;
[newrxns_added] = updateGapRxns(model_original,rxn,'',strains,inputpath,outputpath,'strict',0);
newrxns = newrxns_added;
[newrxns_added] = updateGapRxns(model_original,rxn_onlyonetype,'',strains,inputpath,outputpath,'loose',0);
newrxns = [newrxns;newrxns_added];
clearvars -EXCEPT newrxns panmodel model_original newrxns_added strains inputpath


%% Step 2 This Step is to check for each biomass composition
% trp
newtstepcheck = [];
met = {'s_1049[e]'}; % trp
rxns_query(:,1) = {'r_0566','r_0913','r_0203','r_0202','r_5018','r_5018','r_5018'}; % 'RXN0-2381','RXN0-2382' are step rxn for r_5018
rxns_query(:,2) = {'IGPSYN-RXN','PRAISOM-RXN','ANTHRANSYN-RXN','PRTRANS-RXN','TRYPSYN-RXN','RXN0-2381','RXN0-2382'};
rxns_query(:,3) = {'R03508','R03509','R00986','R01073','R02722','R02340','R00674'};
precursors = {'C00251','C00119'};%CHROSIMATE PRPP
comp = {'cytoplasm'};
precursors = model_original.mets(intersect(find(contains(model_original.metKEGGID,precursors)),find(contains(model_original.metNames,comp))));
[newrxns_added] = updateGapRxns(model_original,rxns_query,met,strains,inputpath,inputpath,'loose');
newrxns = [newrxns;newrxns_added];
[~,~,~,cannotProduce] = getprecursorMatrixCobra(model_original,strains,inputpath,precursors,1);
newtstepcheck = [newtstepcheck;cannotProduce];
clearvars  rxns_query precursors met

% erg
met = {'s_0666[c]'}; % erg
rxns_query(:,1) = {'r_1011','r_0667','r_0236','r_0237','r_0231','r_1012','r_0558','r_0559','r_0560','r_0667','r_0735','r_0739','r_0904'};
rxns_query(:,2) = {'SQUALENE-MONOOXYGENASE-RXN','IPPISOM-RXN','RXN66-314','RXN66-314','RXN66-306','RXN-13162','IPPISOM-RXN','HYDROXYMETHYLGLUTARYL-COA-SYNTHASE-RXN','DIPHOSPHOMEVALONTE-DECARBOXYLASE-RXN','ACETYL-COA-ACETYLTRANSFER-RXN','1.1.1.34-RXN','PHOSPHOMEVALONATE-KINASE-RXN','MEVALONATE-KINASE-RXN'};
rxns_query(:,3) = {'R02874','R01123','R07495','R07495','R05639','R06223','R01123','R01978','R01121','R00238','R02082','R03245','R02245'};
precursors = {'C00448'};%fpp
comp = {'cytoplasm'};
precursors = model_original.mets(intersect(find(contains(model_original.metKEGGID,precursors)),find(contains(model_original.metNames,comp))));
[newrxns_added] = updateGapRxns(model_original,rxns_query,met,strains,inputpath,inputpath,'loose');
newrxns = [newrxns;newrxns_added];
[~,~,~,cannotProduce] = getprecursorMatrixCobra(model_original,strains,inputpath,precursors,1);
newtstepcheck = [newtstepcheck;cannotProduce];
clearvars  rxns_query precursors met

% PI
met = {'s_0089[c]'}; % PI
rxns_query(:,1) = {'r_0758','r_2454','r_2455','r_2456','r_2457','r_2458','r_2459','r_2460','r_2461'};
rxns_query(:,2) = {'MYO-INOSITOL-1-PHOSPHATE-SYNTHASE-RXN','2.7.8.11-RXN','2.7.8.11-RXN','2.7.8.11-RXN','2.7.8.11-RXN','2.7.8.11-RXN','2.7.8.11-RXN','2.7.8.11-RXN','2.7.8.11-RXN'}; %D-glucopyranose 6-phosphate ? 1D-myo-inositol 3-monophosphate
rxns_query(:,3) = {'R02874','R01802','R01802','R01802','R01802','R01802','R01802','R01802','R01802'};
[newrxns_added] = updateGapRxns(model_original,rxns_query,met,strains,inputpath,inputpath,'loose');
newrxns = [newrxns;newrxns_added];
clearvars  rxns_query precursors met

%PS
met = {'s_1337[c]'}; % PS
precursors = {'C00065','C00083'}; % serine mal-coA
precursors = model_original.mets(intersect(find(contains(model_original.metKEGGID,precursors)),find(contains(model_original.metNames,comp))));
rxns_query(:,1) = {'r_2446','r_2447','r_2448','r_2449','r_2450','r_2451','r_2452','r_2453','r_2432','r_2433','r_2434','r_2435','r_2436','r_2437','r_2438','r_2439','r_2332','r_2333','r_2334','r_2335','r_2336','r_2337','r_2338','r_2339','r_2182'};
rxns_query(:,2) = {'PHOSPHASERSYN-RXN','PHOSPHASERSYN-RXN','PHOSPHASERSYN-RXN','PHOSPHASERSYN-RXN','PHOSPHASERSYN-RXN','PHOSPHASERSYN-RXN','PHOSPHASERSYN-RXN','PHOSPHASERSYN-RXN','CDPDIGLYSYN-RXN','CDPDIGLYSYN-RXN','CDPDIGLYSYN-RXN','CDPDIGLYSYN-RXN','CDPDIGLYSYN-RXN','CDPDIGLYSYN-RXN','CDPDIGLYSYN-RXN','CDPDIGLYSYN-RXN','CDPDIGLYSYN-RXN','CDPDIGLYSYN-RXN','CDPDIGLYSYN-RXN','CDPDIGLYSYN-RXN','CDPDIGLYSYN-RXN','CDPDIGLYSYN-RXN','CDPDIGLYSYN-RXN','CDPDIGLYSYN-RXN','RXN-10664'};
rxns_query(:,3) = {'R01800','R01800','R01800','R01800','R01800','R01800','R01800','R01800','R01799','R01799','R01799','R01799','R01799','R01799','R01799','R01799','R01799','R01799','R01799','R01799','R01799','R01799','R01799','R01799','R02222'};
[newrxns_added] = updateGapRxns(model_original,rxns_query,met,strains,inputpath,inputpath,'loose');
newrxns = [newrxns;newrxns_added];
[~,~,~,cannotProduce] = getprecursorMatrixCobra(model_original,strains,inputpath,precursors,1);
newtstepcheck = [newtstepcheck;cannotProduce];
clearvars  rxns_query precursors met

%PC
met = {'s_1346[c]'}; % PC
precursors = {'C00570'}; % ethanolamine
comp = {'endoplasmic reticulum membrane'};
precursors = model_original.mets(intersect(find(contains(model_original.metKEGGID,precursors)),find(contains(model_original.metNames,comp))));
rxns_query(:,1) = {'r_2504','r_2505','r_2506','r_2507','r_2508','r_2509','r_2510','r_2511','r_2496','r_2497','r_2498','r_2499','r_2500','r_2501','r_2502','r_2503','r_2488','r_2489','r_2490','r_2491','r_2492','r_2493','r_2494','r_2495','r_2520','r_2521','r_2522','r_2523','r_2524','r_2525','r_2526','r_2527','r_2182'};
rxns_query(:,2) = {'RXN4FS-2','RXN4FS-2','RXN4FS-2','RXN4FS-2','RXN4FS-2','RXN4FS-2','RXN4FS-2','RXN4FS-2','2.1.1.71-RXN','2.1.1.71-RXN','2.1.1.71-RXN','2.1.1.71-RXN','2.1.1.71-RXN','2.1.1.71-RXN','2.1.1.71-RXN','2.1.1.71-RXN','2.1.1.17-RXN','2.1.1.17-RXN','2.1.1.17-RXN','2.1.1.17-RXN','2.1.1.17-RXN','2.1.1.17-RXN','2.1.1.17-RXN','2.1.1.17-RXN','ETHANOLAMINEPHOSPHOTRANSFERASE-RXN','ETHANOLAMINEPHOSPHOTRANSFERASE-RXN','ETHANOLAMINEPHOSPHOTRANSFERASE-RXN','ETHANOLAMINEPHOSPHOTRANSFERASE-RXN','ETHANOLAMINEPHOSPHOTRANSFERASE-RXN','ETHANOLAMINEPHOSPHOTRANSFERASE-RXN','ETHANOLAMINEPHOSPHOTRANSFERASE-RXN','ETHANOLAMINEPHOSPHOTRANSFERASE-RXN','RXN-10664'};
rxns_query(:,3) = {'R01320','R01320','R01320','R01320','R01320','R01320','R01320','R01320','R03424','R03424','R03424','R03424','R03424','R03424','R03424','R03424','R02056','R02056','R02056','R02056','R02056','R02056','R02056','R02056','R02057','R02057','R02057','R02057','R02057','R02057','R02057','R02057','R12173'};
[newrxns_added] = updateGapRxns(model_original,rxns_query,met,strains,inputpath,inputpath,'loose');
newrxns = [newrxns;newrxns_added];
[~,~,~,cannotProduce] = getprecursorMatrixCobra(model_original,strains,inputpath,precursors,1);
newtstepcheck = [newtstepcheck;cannotProduce];
clearvars  rxns_query precursors met

%man
met = {'s_1107[c]'}; % man
precursors = {'C00636'};%mannose1p
comp = {'cytoplasm'};
precursors = model_original.mets(intersect(find(contains(model_original.metKEGGID,precursors)),find(contains(model_original.metNames,comp))));
rxns_query(:,1) = {'r_0361','r_0722','r_0902','r_0723'}; %all have r_0362 r_1933
rxns_query(:,2) = {'2.4.1.83-RXN','2.7.7.13-RXN','PHOSMANMUT-RXN','MANNPISOM-RXN'};
rxns_query(:,3) = {'R01009','R00885','R01818','R00772'};
[newrxns_added] = updateGapRxns(model_original,rxns_query,met,strains,inputpath,inputpath,'loose');
newrxns = [newrxns;newrxns_added];
[~,~,~,cannotProduce] = getprecursorMatrixCobra(model_original,strains,inputpath,precursors,1);
newtstepcheck = [newtstepcheck;cannotProduce];
clearvars  rxns_query precursors met

% riboflavin
met = {'s_1405[c]'}; % riboflavin
precursors = {'C00199'};
comp = {'cytoplasm'};
precursors = model_original.mets(intersect(find(contains(model_original.metKEGGID,precursors)),find(contains(model_original.metNames,comp))));
rxns_query(:,1) = {'r_0525','r_0440','r_0038','r_0014','r_0015','r_2030','r_0965','r_0968','r_0967'}; %r
rxns_query(:,2) = {'GTP-CYCLOHYDRO-II-RXN','FADSYN-RXN','DIOHBUTANONEPSYN-RXN','RXN-10058','RXN-10057','RIBOPHOSPHAT-RXN','RIBOFLAVINKIN-RXN','RIBOFLAVIN-SYN-RXN','LUMAZINESYN-RXN'};
rxns_query(:,3) = {'R00425','R00161','R07281','R09377','R09376','R07280','R00549','R00066','R04457'};
[newrxns_added] = updateGapRxns(model_original,rxns_query,met,strains,inputpath,inputpath,'loose');
newrxns = [newrxns;newrxns_added];
[~,~,~,cannotProduce] = getprecursorMatrixCobra(model_original,strains,inputpath,precursors,1);
newtstepcheck = [newtstepcheck;cannotProduce];
clearvars  rxns_query precursors met

% DNA
precursors = {'C00049';'C00169'};
comp = {'cytoplasm'};
rxns_query(:,1) = {'r_0214','r_0250','r_0349','r_0820','r_0821'};
rxns_query(:,3) = {'R00575','R01397','R01993','R01870','R00965'};
rxns_query(:,2) = {'CARBPSYN-RXN','ASPCARBTRANS-RXN','DIHYDROOROT-RXN','OROPRIBTRANS-RXN','OROTPDECARB-RXN'};
[newrxns_added] = updateGapRxns(model_original,rxns_query,'',strains,inputpath,inputpath,'strict',0);
newrxns = [newrxns;newrxns_added];
clearvars  rxns_query precursors met

% one critical rxn r_0883 TDP
met = {'s_1475[c]'}; %
rxns_query(:,1) = {'r_0883','r_0061'}; %r_0883 for TDP; r_0061 for leucine
rxns_query(:,2) = {'1.8.4.8-RXN','3-ISOPROPYLMALDEHYDROG-RXN'};
rxns_query(:,3) = {'R02021','R04426'};
[newrxns_added] = updateGapRxns(model_original,rxns_query,met,strains,inputpath,inputpath,'loose');
newrxns = [newrxns;newrxns_added];
clearvars  rxns_query precursors met

% fix H2O diffusion    
[~,rxnMatrix,~,~] = getprecursorMatrixCobra(model_original,strains,inputpath,[],1);
[~,idx] = ismember('r_1277',model_original.rxns);
strains_nowater = strains(rxnMatrix(:,idx) == 0);
current_path = pwd;
for i = 1:length(strains_nowater)
    cd(inputpath)
    m = strains_nowater{i};
    reducedModel = load([m,'.mat']);
    reducedModel = reducedModel.reducedModel;
    cd(current_path)
    reducedModel = addrxnBack(reducedModel,model_original,{'r_1277'},{''});
    newrxns_added = [newrxns_added;{'r_1277'},m,{''},{'water diffusion'}];
    cd(inputpath)
    save([m,'.mat'],'reducedModel')
end
newrxns = [newrxns;newrxns_added];

% fix ATP transport   
cd(current_path)
[~,rxnMatrix,~,~] = getprecursorMatrixCobra(model_original,strains,inputpath,[],1);
[~,idx] = ismember('r_1110',model_original.rxns);
strains_noATPtransport = strains(rxnMatrix(:,idx) == 0);
for i = 1:length(strains_noATPtransport)
    cd(inputpath)
    m = strains_noATPtransport{i};
    reducedModel = load([m,'.mat']);
    reducedModel = reducedModel.reducedModel;
    cd(current_path)
    reducedModel = addrxnBack(reducedModel,model_original,{'r_1110'},{''});
    newrxns_added = [newrxns_added;{'r_1110'},m,{''},{'water diffusion'}];
    cd(inputpath)
    save([m,'.mat'],'reducedModel')
end
newrxns = [newrxns;newrxns_added];

cd(current_path)
rxn_added_pathway{1} = newrxns;
rxn_added_pathway{2} = newtstepcheck;
save(['../modelRelated/rxn_added_pathway',strains{1},'.mat'],'rxn_added_pathway')
clearvars   rxn_added_pathway
%% step 3 fix alternative pwys gap
% load new rxn and new metabolites and generate three tsv files for next step: adding new rxns and mets into the model
% mapping metaNetIDs
cd(current_path)
format = '%s %s %s %s %s %s %s %s %s %s %s';
fID       = fopen('../../data/gapfill/new_met_information_gapfill.txt');
matrixData  = textscan(fID,format,'Delimiter','\t','HeaderLines',1);
matrix.rxnIDs      = matrixData{1};
matrix.mettype = matrixData{2};
matrix.metcoef  = cellfun(@str2num, matrixData{3});
matrix.metcompartments = matrixData{11};
newmet.metNames         = matrixData{7};
newmet.metFormulas      = matrixData{5};
newmet.metCharges       = cellfun(@str2num,replace(matrixData{6},'NA','0'));
newmet.metKEGGID        = matrixData{9};
newmet.metChEBIID       = matrixData{8};
newmet.metMetaNetXID    = matrixData{4};
fclose(fID);

% Matching newmat with existing mets in the model through mapping MNXID,
% CHEBI ID and KEGG ID. model should be in cobra format
[~,ID] = ismember(newmet.metMetaNetXID,model_original.metMetaNetXID);
metname_temp = split(model_original.metNames(ID(ID~=0)),' [');
metname_temp = cellstr(metname_temp(:,1));
newmet.metNames(ID~=0) = metname_temp;
matrix.metIDs = newmet.metNames;

fID       = fopen('../../data/gapfill/new_rxn_information_gapfill.txt');
rxnData = textscan(fID,'%s %s %s %s %s %s %s %s %s %s %s','Delimiter','\t','HeaderLines',1);
newrxn.ID  = rxnData{1};
newrxn.Rev = cellfun(@str2num, rxnData{8});
newrxn.GPR = rxnData{6};
newrxn.rxnNames     = rxnData{2};
newrxn.rxnNotes = rxnData{3};
newrxn.rxnKEGGID      = rxnData{9};
newrxn.strains = rxnData{4};
newrxn.rxnECNumbers = rxnData{7};
newrxn.rxnMetaNetXID = rxnData{11};
fclose(fID);
[model_original,rxnUpdateGPR] = addPanModelRxn(model_original,matrix,newmet,newrxn);

current_path = pwd;
newrxns_added = [];
for i = 1:length(newrxn.ID)
    strainslist = newrxn.strains(i);
    strainslist = split(strainslist,',');
    strainslist = strrep(strainslist,' ','');
    strainslist = strrep(strainslist,'"','');
    [~,idx] = ismember(lower(strainslist),lower(strains));
    [~,rxnIdx] = ismember(newrxn.ID(i,1),model_original.rxnMetaNetXID);
    if rxnIdx == 0
        [~,rxnIdx] = ismember(newrxn.ID(i,1),model_original.rxnKEGGID);
    end
    for j = 1:length(idx)
        if idx(j) ~=0
            m = strains{idx(j)};
            cd(inputpath)
            reducedModel = load([m,'.mat']);
            reducedModel = reducedModel.reducedModel;
            cd(current_path)
            reducedModel = addrxnBack(reducedModel,model_original,model_original.rxns(rxnIdx),model_original.grRules(rxnIdx));
            newrxns_added = [newrxns_added;model_original.rxns(rxnIdx),m,{''},{'alternative_pwy'}];
            cd(inputpath)
            save([m,'.mat'],'reducedModel')
        else
            warning(['no species found for',strainslist{j}])
        end
    end
end
cd(current_path)
newrxns = [newrxns;newrxns_added];

%% step 4 fix oxidative repiration chain adding those reactions back if not
% exist
[newrxns_added] = RespiratoryChain(model_original,strains,inputpath);
newrxns = [newrxns;newrxns_added];
save(['../modelRelated/newrxns_alternativapwy',strains{1},'.mat'],'newrxns')

%% step 5 Auto-gap-filling rxns
[proMarix,rxnMatrix,mets_test] = getprecursorMatrixCobra(model_original,strains,inputpath);
panmodel = ravenCobraWrapper(model_original);
panmodel.id = 'panmodel';
panmodel = setParam(panmodel,'lb',{'r_4046'},0);
cd(inputpath)
newrxns_added = {};
for i = 1:length(strains)
    i
    m = strains{i};
    load([m,'.mat'])
    sol = solveLP(reducedModel);
    
    if isempty(sol.f) | ~any(sol.f)
        id = reducedModel.id;
        if ~isfield(reducedModel,'metComps')
            reducedModel = ravenCobraWrapper(reducedModel);
        end
        reducedModel.id = id;
        if isfield(reducedModel,'metNotes')
        reducedModel = rmfield(reducedModel,'metNotes');
        end
        if isfield(panmodel,'metNotes')
        panmodel = rmfield(panmodel,'metNotes');
        end

        reducedModel = setParam(reducedModel,'eq',{'r_2111'},0.001);
        [~, ~, addedRxns, reducedModel] = fillGaps(reducedModel,{panmodel},'useModelConstraints',true);
        reducedModel = setParam(reducedModel,'lb',{'r_2111'},0);
        reducedModel = setParam(reducedModel,'ub',{'r_2111'},1000);
        sol = optimizeCbModel(reducedModel,'max');
        newrxns_added = [newrxns_added;addedRxns,repmat(strains(i),length(addedRxns),1)];
    end
end
cd(current_path)
save(['../modelRelated/newrxns_auotgap',strains{1},'.mat'],'newrxns_added')

% add those reactions back to the model
strains_specific = unique(newrxns_added(:,2));
for i = 1:length(strains_specific)
    cd(inputpath)
    load([strains_specific{i},'.mat'])
    idx = find(contains(newrxns_added(:,2),strains_specific(i)));
    for j = 1:length(idx)
        cd(current_path)
        if ~endsWith(newrxns_added(idx(j),1),'_panmodel') % fix the error of raven auto gapfilling, it would generate r_xxxx_panmodel
            reducedModel = addrxnBack(reducedModel,model_original,newrxns_added(idx(j),1),{''});
        end
    end
    
    cd(inputpath)
    save([strains_specific{i},'.mat'],'reducedModel')
    %saveSSModel(reducedModel,'false');
end
cd(current_path)
cd ../
