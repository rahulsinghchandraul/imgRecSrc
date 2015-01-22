function [conf,opt] = runLasso(runList)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%      Beam Hardening correction of CT Imaging via Mass attenuation 
%                        coefficient discretizati
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   Author: Renliang Gu (renliang@iastate.edu)
%   $Revision: 0.2 $ $Date: Thu 22 Jan 2015 03:16:34 PM CST
%   v_0.2:      Changed to class oriented for easy configuration

if(nargin==0 || ~isempty(runList))
    filename = [mfilename '.mat'];
    if( exist(filename,'file') ) load(filename);
    else save(filename,'filename');
    end
end

if(nargin==0) runList = [0];
elseif(isempty(runList))
    [conf, opt] = defaultInit();
    opt = conf.setup(opt);
end

%%%%%%%%%%%%%%%%%%%%%%%%
if(any(runList==0)) % reserved for debug and for the best result
    [conf, opt] = defaultInit();
    i=1; j=1;
    conf.imgSize = 256;
    conf.prjWidth = 256;
    conf.prjFull = 360/6;
    conf.prjNum = conf.prjFull/2;
    conf.PhiMode='cpuPrj'; %'basic'; %'filtered'; %'weighted'; %
    conf.imageName='phantom'; %'castSim'; %'phantom' %'twoMaterials'; 

    opt.alphaStep='NPGs'; %'SpaRSA'; %'NCG_PR'; %'ADMM_L1'; %
    opt=conf.setup(opt);
    opt.u=1e-4;
    opt.thresh=1e-14;
    opt.maxItr=1e3;
    opt.debugLevel=6;
    %conf.y=conf.y+randn(size(conf.y))*sqrt(1e-8*(norm(conf.y(:)).^2)/length(conf.y(:)));
    prefix='Lasso';
    fprintf('%s, i=%d, j=%d\n',prefix,i,j);
    initSig = conf.FBP(conf.y);
    initSig = initSig(opt.mask~=0);
    %initSig = opt.trueAlpha;
    %initSig = out0.alpha;
    out0=lasso(conf.Phi,conf.Phit,...
        conf.Psi,conf.Psit,conf.y,initSig,opt);
    save(filename,'out0','-append');
end

% This section is used to compare different methods for lasso *with* 
% non-negativity constraints
if(any(runList==1)) % FISTA_NNL1
    [conf, opt] = defaultInit();
    i=1; j=1;
    conf.imgSize = 256;
    conf.prjWidth = 256;
    conf.prjFull = 360/6;
    conf.prjNum = conf.prjFull/2;
    conf.PhiMode='cpuPrj'; %'basic'; %'filtered'; %'weighted'; %
    conf.imageName='phantom'; %'castSim'; %'phantom' %'twoMaterials'; 

    opt=conf.setup(opt);

    opt.u=1e-4;
    opt.debugLevel=1;
    opt.alphaStep='NPG';%'SpaRSA'; %'NCG_PR'; %'ADMM_L1'; %
    %conf.y=conf.y+randn(size(conf.y))*sqrt(1e-8*(norm(conf.y(:)).^2)/length(conf.y(:)));
    %opt=conf.loadLasso(opt);
    prefix='Lasso';
    fprintf('%s, i=%d, j=%d\n',prefix,i,j);
    initSig = conf.FBP(conf.y);
    initSig = initSig(opt.mask~=0);
    %initSig = opt.trueAlpha;
    opt.maxItr=1000;
    %initSig = out1.alpha;
    opt.u=1e-2;
    for i=1:9
        opt.u=opt.u*0.1;
        out2{i}=lasso(conf.Phi,conf.Phit,...
            conf.Psi,conf.Psit,conf.y,initSig,opt);
        initSig=out2{i}.alpha;
        save(filename,'out2','-append');
    end
end

% This section is used to compare different methods for lasso *without* 
% non-negativity constraints
if(any(runList==2))
    [conf, opt] = defaultInit();
    i=1; j=1;
    conf.imgSize = 256;
    conf.prjWidth = 256;
    conf.prjFull = 360/6;
    conf.prjNum = conf.prjFull/2;
    conf.PhiMode='cpuPrj'; %'basic'; %'filtered'; %'weighted'; %
    conf.imageName='phantom'; %'castSim'; %'phantom' %'twoMaterials'; 

    opt=conf.setup(opt);

    opt.u=1e-4;
    opt.debugLevel=6;
    opt.alphaStep='NPGs';%'SpaRSA'; %'NCG_PR'; %'ADMM_L1'; %
    
    %conf.y=conf.y+randn(size(conf.y))*sqrt(1e-8*(norm(conf.y(:)).^2)/length(conf.y(:)));
    %opt=conf.loadLasso(opt);
    prefix='Lasso';
    fprintf('%s, i=%d, j=%d\n',prefix,i,j);
    initSig = conf.FBP(conf.y);
    initSig = initSig(opt.mask~=0);
    %initSig = opt.trueAlpha;
    %initSig = out0.alpha;

    out2=lasso(conf.Phi,conf.Phit,...
        conf.Psi,conf.Psit,conf.y,initSig,opt);
    save(filename,'out2','-append');
end

if(any(runList==3)) % SPIRAL-G
    [conf, opt] = defaultInit();
    i=1; j=1;
    conf.imgSize = 256;
    conf.prjWidth = 256;
    conf.prjFull = 360/6;
    conf.prjNum = conf.prjFull/2;
    conf.PhiMode='cpuPrj'; %'basic'; %'filtered'; %'weighted'; %
    conf.imageName='phantom_1'; %'castSim'; %'phantom' %'twoMaterials'; 

    opt=conf.setup(opt);

    opt.u=1e-4;
    opt.debugLevel=1;
    initSig = conf.FBP(conf.y);
    initSig = initSig(opt.mask~=0);
    %initSig = opt.trueAlpha;
    %initSig = out1.alpha;
    opt.alphaStep='NPG';%'SpaRSA'; %'NCG_PR'; %'ADMM_L1'; %
    subtolerance=1e-6;
    out=[];
    [out.alpha, out.p, out.cost, out.reconerror, out.time, ...
        out.solutionpath] = ...
        SPIRALTAP_mod(conf.y,conf.Phi,opt.u,'penalty','ONB',...
        'AT',conf.Phit,'W',conf.Psi,'WT',conf.Psit,'noisetype','gaussian',...
        'initialization',initSig,'maxiter',opt.maxItr,...
        'miniter',0,'stopcriterion',3,...
        'tolerance',opt.thresh,'truth',opt.trueAlpha,...
        'subtolerance',subtolerance,'monotone',1,...
        'saveobjective',1,'savereconerror',1,'savecputime',1,...
        'reconerrortype',2,...
        'savesolutionpath',1,'verbose',100);
    out_phantom_1_spiral_monotone=out;
    save(filename,'out_phantom_1_spiral_monotone','-append');
    out_phantom_1_NPG_a8=lasso(conf.Phi,conf.Phit,...
        conf.Psi,conf.Psit,conf.y,initSig,opt);
    save(filename,'out_phantom_1_NPG_a8','-append');
end

if(any(runList==999))
    % compare DORE version and FISTA for naive lasso
    conf=ConfigCT();
    conf.beamharden=false;
    conf.prjFull = 360/6;
    conf.prjNum = conf.prjFull/2;
    conf.imgSize = 256;
    conf.prjWidth = 256;
    conf.imageName='phantom_1'; %'castSim'; %'phantom' %'twoMaterials'; 

    opt=conf.setup();
    opt.thresh=1e-14;
    opt.maxItr=2e3;
    opt.debugLevel=5;
    opt.showImg=true;
    opt.alphaStep='NPGs'; %'SpaRSA'; %'NCG_PR'; %'ADMM_L1'; %
    opt.u=1e-4;
    initSig = maskFunc(conf.FBP(conf.y),opt.mask~=0);
    %initSig=opt.trueAlpha;
    out999=lasso(conf.Phi,conf.Phit,...
        conf.Psi,conf.Psit,conf.y,initSig,opt);
    save(filename,'out999','-append');
    % Conlusion: Double overrelaxation is worse than one overrelaxation.  
    % when there is not sparsity constraints. And overrelaxations are 
    % equivalent or even better than FISTA. Of course, all are better than 
    % gradient method.
    %
    % When apply the sparsity constraints, 
end
end

