% This configuration file is used for RealCT data and the analytically 
% simulated Phantom data. The sinogram is first transformed to frequency 
% domain, if the length of every projection is N, then the reconstructed image 
% should have a size of NxN.

% Author: Renliang Gu (renliang@iastate.edu)
% $Revision: 0.2 $ $Date: Wed 06 Jan 2016 11:07:48 PM CST
% v_0.3:        change the structure to make ConfigCT generate operators only.
% v_0.2:        change the structure to class for easy control;

classdef ConfigCT < handle
    properties
        % parameters for operators
        PhiMode = 'cpuPrj'; %'parPrj'; %'basic'; %'gpuPrj'; %
        imgSize = 1024;
        prjWidth = 1024;
        prjFull = 360;
        prjNum = 180;
        dSize = 1;
        effectiveRate = 1;
        dist = 0;       % default to be parallel beam
        Ts = 1;
    end 
    methods
        function obj = ConfigCT(ot)
            if(nargin>0) obj.PhiMode = ot; end
        end
        % whenever set the PhiMode to gpu, test the availability of GPU
        function set.PhiMode(obj,ot)
            if(strcmpi(ot,'gpuPrj'))
                if(gpuDeviceCount==0)
                    warning('There is no GPU equipped, downgrade to use cpuPrj!')
                    obj.PhiMode='cpuPrj';
                else
                    obj.PhiMode='gpuPrj';
                end
            else
                obj.PhiMode=ot;
            end
        end
        function opt=setup(obj,opt)
            % obsoleted function
            if(nargin==1) opt=[]; end;
            if(~isfield(opt,'snr')) opt.snr=inf; end
            if(~isfield(opt,'noiseType')) opt.noiseType='gaussian'; end

            fprintf('Loading data...\n');
            opt.machine=system_dependent('getos');
            opt.hostname=evalc('!hostname');
            switch lower(obj.imageName)
                case 'phantom_1'
                    loadPhantom_1(obj);
                case 'phantom'
                    loadPhantom(obj,opt.snr,opt.noiseType);
                case lower('castSim')
                    loadCastSim(obj);
                case lower('glassBeadsSim')
                    loadGlassBeadsSim(obj,opt.snr,opt.noiseType);
                case lower('twoMaterials')
                    loadTwoMaterials(obj);
                case 'realct'
                    loadRealCT(obj);
                case 'pellet'
                    loadPellet(obj);
                case 'lasso'
                    loadLasso(obj);
                case 'wrist'
                    loadWrist(obj,opt.snr,opt.noiseType);
            end
            genOperators(obj,obj.PhiMode);

            if(obj.beamharden)
                opt.kappa= obj.trueKappa;
                opt.iota= obj.trueIota;
                opt.epsilon= obj.epsilon;
            end
            opt.mask=obj.mask;
            maskIdx = find(obj.mask~=0);
            wvltIdx = find(obj.maskk~=0);
            
            %Sampling operator
            W=@(z) midwt(z,obj.wav,obj.dwt_L);
            Wt=@(z) mdwt(z,obj.wav,obj.dwt_L);

            obj.Psi = @(s) maskFunc(W (maskFunc(s,wvltIdx,obj.imgSize)),maskIdx);
            obj.Psit= @(x) maskFunc(Wt(maskFunc(x,maskIdx,obj.imgSize)),wvltIdx);
            fprintf('Configuration Finished!\n');
        end

        function [Phi,Phit,FBP]=nufftOps(obj,mask)
            m_2D=[obj.imgSize, obj.imgSize];
            J=[1,1]*3;                       % NUFFT interpolation neighborhood
            K=2.^ceil(log2(m_2D*2));         % oversampling rate
            theta = (0:obj.prjNum-1)*360/obj.prjFull;

            r=pi*linspace(-1,1-2/obj.prjWidth,obj.prjWidth)';
            xc=r*cos(theta(:)'*pi/180);
            yc=r*sin(theta(:)'*pi/180);
            om=[yc(:), xc(:)];
            st=nufft_init(om,m_2D,J,K,m_2D/2,'minmax:kb');
            st.Num_pixel=obj.prjWidth;
            st.Num_proj=obj.prjNum;

            % Zero freq at f_coeff(prjWidth/2+1)
            Phi=@(s) PhiFunc51(s,0,st,obj.imgSize,obj.Ts,mask);
            Phit=@(s) PhitFunc51(s,0,st,obj.imgSize,obj.Ts,mask);
            FBP=@(s) FBPFunc6(s,theta,obj.Ts);
        end
        function [Phi,Phit,FBP]=cpuFanParOps(obj,mask)
            conf.n=obj.imgSize; conf.prjWidth=obj.prjWidth;
            conf.np=obj.prjNum; conf.prjFull=obj.prjFull;
            conf.dSize=obj.dSize; %(n-1)/(Num_pixel+1);
            conf.effectiveRate=obj.effectiveRate;
            conf.d=obj.dist;

            cpuPrj(0,conf,'config');
            %mPrj(0,0,'showConf');
            Phi =@(s) cpuPrj(mask.b(s),0,'forward')*obj.Ts;
            Phit=@(s) mask.a(cpuPrj(s,0,'backward'))*obj.Ts;
            FBP =@(s) cpuPrj(s,0,'FBP')/obj.Ts;
        end
        function [Phi,Phit,FBP]=gpuFanParOps(obj,mask)
            conf.n=obj.imgSize; conf.prjWidth=obj.prjWidth;
            conf.np=obj.prjNum; conf.prjFull=obj.prjFull;
            conf.dSize=obj.dSize; %(n-1)/(Num_pixel+1);
            conf.effectiveRate=obj.effectiveRate;
            conf.d=obj.dist;

            gpuPrj(0,conf,'config');
            %mPrj(0,0,'showConf');
            Phi =@(s) gpuPrj(mask.b(s),0,'forward')*obj.Ts;
            Phit=@(s) mask.a(gpuPrj(s,0,'backward'))*obj.Ts;
            %cpuPrj(0,conf,'config');
            FBP =@(s) gpuPrj(s,0,'FBP')/obj.Ts;
        end
        function [Phi,Phit,FBP]=genOperators(obj,maskmt)
            if(~exist('maskmt','var') || isempty(maskmt))
                fprintf('No mask is applied\n');
                mask.a=@(xx) xx;
                mask.b=@(xx) xx;
            else
                maskIdx=find(maskmt~=0);
                n=size(maskmt);
                mask.a=@(xx) maskFunc(xx,maskIdx);
                mask.b=@(xx) maskFunc(xx,maskIdx,n);
            end
            switch lower(obj.PhiMode)
                case 'basic'
                    [Phi,Phit,FBP]=nufftOps(obj,mask);
                case lower('cpuPrj')
                    % can be cpu or gpu, with both fan or parallel projections
                    [Phi,Phit,FBP]=cpuFanParOps(obj,mask);
                case lower('gpuPrj')
                    % can be cpu or gpu, with both fan or parallel projections
                    [Phi,Phit,FBP]=gpuFanParOps(obj,mask);
                case lower('parPrj')
                    conf.bw=1; conf.nc=obj.imgSize; conf.nr=obj.imgSize; conf.prjWidth=obj.prjWidth;
                    conf.theta = (0:obj.prjNum-1)*360/obj.prjFull;
                    maskIdx = find(mask~=0);
                    Phi = @(s) mParPrj(s,maskIdx-1,conf,'forward')*obj.Ts;
                    Phit= @(s) mParPrj(s,maskIdx-1,conf,'backward')*obj.Ts;
                    FBP = @(s) FBPFunc7(s,obj.prjFull,obj.prjNum,obj.Ts,maskIdx)*obj.Ts;
                case 'weighted'
                    % Fessler's weighted methods
                    weight=exp(-y);
                    %weight=exp(-ones(size(y)));
                    weight=sqrt(weight/max(weight(:)));
                    y=y.*weight;

                    Phi=@(s) PhiFunc51(s,f_coeff,st,mx,Ts,mask).*weight(:);
                    Phit=@(s) PhitFunc51(s.*weight(:),f_coeff,st,mx,...
                        Ts,mask);
                    FBP=@(s) FBPFunc6(s./weight,theta_idx,Ts);
                case 'filtered'
                    % Sqrt filtered methods
                    y=reshape(y(:),Num_pixel,Num_proj);
                    y=[zeros(Num_pixel/2,Num_proj); y; zeros(Num_pixel/2,Num_proj)];
                    y=fft(fftshift(y,1))*Ts;
                    y=y.*repmat(sqrt(f_coeff),1,Num_proj);
                    y=fftshift(ifft(y),1)/Ts;
                    y=y(Num_pixel/2+1:Num_pixel/2+Num_pixel,:);
                    y=real(y(:));

                    Phi=@(s) PhiFunc2(s,f_coeff,stFwd,Num_pixel,Ts,maskIdx);
                    Phit=@(s) PhitFunc2(s,f_coeff,stFwd,Num_pixel,Ts,maskIdx);
                    FBP=Phit;
                otherwise
                    error(sprintf('Wrong mode for PhiMode: %s\n',obj.PhiMode));
            end
        end
        function fan2parallel()
            [temp1, ploc1, ptheta1]=...
                fan2paraM(CTdata,dist*Ts,'FanSensorGeometry','line',...
                'FanSensorSpacing',Ts,'ParallelCoverage','halfcycle',...
                'Interpolation','pchip','ParallelRotationIncrement',paraInc,...
                'PerpenCenter',perpenCenter,'RotationCenter',rotationCenter,...
                'ParallelSensorSpacing',Ts*ds);

            [temp2, ploc2, ptheta2]=...
                fan2paraM(CTdata(:,[181:360 1:180]),dist*Ts,...
                'FanSensorGeometry','line',...
                'FanSensorSpacing',Ts,'ParallelCoverage','halfcycle',...
                'Interpolation','pchip','ParallelRotationIncrement',paraInc,...
                'PerpenCenter',perpenCenter,'RotationCenter',rotationCenter,...
                'ParallelSensorSpacing',Ts*ds); %fss*ds);  %

            temp2=temp2(end:-1:1,:);
            ploc2=-ploc2(end:-1:1);
            lowerBound=max(ploc1(1),ploc2(1));
            upperBound=min(ploc1(end),ploc2(end));
            if(lowerBound==ploc1(1))
                ploc=ploc2; ploc2=ploc1;
                CTdata=temp2; temp2=temp1;
            else
                ploc=ploc1;
                CTdata=temp1;
            end
            idx1=find(ploc<lowerBound);
            idx2=find((ploc>=lowerBound) & (ploc <=upperBound));
            idx3=idx1+length(ploc);
            ploc(idx3)=ploc2(end-length(idx3)+1:end);
            CTdata=[CTdata; zeros(length(idx3),size(CTdata,2))];
            CTdata([idx2;idx3],:)=CTdata([idx2;idx3],:)+temp2;
            CTdata(idx2,:)=CTdata(idx2,:)/2;
            % Try to reduce the affect of beam harden
            % filt = (.74 + .26 * cos(pi*(-Num_pixel/2:Num_pixel/2-1)/Num_pixel));
            % CTdata=CTdata.*repmat(filt(:),1,Num_proj);
            % aaa=10^-0.4;
            % CTdata=(exp(aaa*CTdata)-1)/aaa;
        end
        function junk(obj)
            Mask=double(Mask~=0);
            %figure; showImg(Mask);
            wvltIdx=find(maskk~=0);
            p_I=length(wvltIdx);
            maskIdx=find(Mask~=0);
            p_M=length(maskIdx);

            fprintf('Generating Func handles...\n');
            m=imgSize^2;

            H=@(s) Phi(Psi(s));
            Ht=@(s) Psit(Phit(s));

            if(0)
                testTranspose(Phi,Phit,N,m,'Phi');
                testTranspose(PhiM,PhiMt,N,p_M,'PhiM');
                %   testTranspose(Psi,Psit,m,m,'Psi');
                %   testTranspose(PsiM,PsiMt,p_M,p_I,'PsiM');
            end

            c=8.682362e-03;
            mc=1;
            mc=0.7;
            mc=6.8195e-03;    % For full projection
            %mc=1.307885e+01;
            if(0)
                %c=expectHHt(H,Ht,N,m,'H');
                c=expectHHt(Phi,Phit,N,m,'Phi');
                %mc=expectHHt(HM,HMt,N,p_I,'HM');
                mc=expectHHt(PhiM,PhiMt,N,p_M,'PhiM');
            end

            img=zeros(size(Img2D));
            img(567:570,787:790)=1;
            %y=Phi(img);
        end
    end
end

