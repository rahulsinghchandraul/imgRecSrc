function yangEx(op)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Polychromatic Sparse Image Reconstruction and Mass Attenuation Spectrum 
%            Estimation via B-Spline Basis Function Expansion
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   Author: Renliang Gu (renliang@iastate.edu)
%   v_0.2:  Changed to class oriented for easy configuration

% "Yang" fish simulated example
% for this example, tviso > tvl1 > wavelet
 
if(~exist('op','var')) op='run'; end

switch lower(op)
    case 'run'
        filename = [mfilename '.mat'];
        if(~exist(filename,'file')) save(filename,'filename'); else load(filename); end
        clear('OPT'); filename = [mfilename '.mat'];

        OPT.beamharden=true; OPT.spectBasis='b1'; OPT.E=30;
        OPT.estIe=true; OPT.noiseType='poisson';

        prjFull = [32, 40, 60, 80, 100, 120, 180, 360];
        u  =  10.^[-5  -5   -5   -5   -5   -5 -5 -5];
        for i=length(prjFull)-1:-1:1
            OPT.prjFull = prjFull(i); OPT.prjNum = OPT.prjFull;

            [y,Phi,Phit,Psi,Psit,OPT,FBP]=loadYang(OPT);
            OPT.maxItr=4e3; OPT.thresh=1e-6;

            initSig = maskFunc(FBP(y),OPT.mask~=0);

            j=1;
            fprintf('%s, i=%d, j=%d\n','Filtered Backprojection',i,j);
            fbp{i}.img=FBP(y);
            fbp{i}.alpha=fbp{i}.img(OPT.mask~=0);
            fbp{i}.RMSE=1-(innerProd(fbp{i}.alpha,OPT.trueAlpha)^2)/sqrNorm(OPT.trueAlpha)/sqrNorm(fbp{i}.alpha);
            fprintf('fbp RMSE=%g\n',fbp{i}.RMSE);

            % known ι(κ), NPG
            for j=3:4
                if(i==3)
                    opt=OPT; opt.u=10^(j-3)*u(i); opt.alphaStep='NPG'; opt.proximal='tviso'; opt.skipIe=true;
                    npgTValpha_b1{i,j}=beamhardenSpline(Phi,Phit,Psi,Psit,y,initSig,opt);
                    save(filename);
                    continue;

                    opt=OPT; opt.u=10^(j-3)*u(i); opt.E=100; opt.alphaStep='NPG'; opt.proximal='tviso'; opt.skipIe=true; opt.adaptiveStep=false;
                    npgTValpha_b1_E100_noAdaptive{i,j}=beamhardenSpline(Phi,Phit,Psi,Psit,y,initSig,opt);
                    save(filename);
                    continue;

                    opt=OPT; opt.u=10^(j-3)*u(i); opt.E=100; opt.alphaStep='NPG'; opt.proximal='tviso'; opt.skipIe=true; opt.restart=false;
                    npgTValpha_b1_E100_norestart{i,j}=beamhardenSpline(Phi,Phit,Psi,Psit,y,initSig,opt);
                    save(filename);
                    continue;

                    opt=OPT; opt.u=10^(j-3)*u(i); opt.E=100; opt.alphaStep='NPG'; opt.proximal='tviso'; opt.skipIe=true; opt.restart=false; opt.adaptiveStep=false;
                    npgTValpha_b1_E100_norestart_noAdaptiveStep{i,j}=beamhardenSpline(Phi,Phit,Psi,Psit,y,initSig,opt);
                    save(filename);
                    continue;

                end
                continue;

                opt=OPT; opt.u=10^(j-3)*u(i); opt.E=100; opt.alphaStep='NPG'; opt.proximal='tviso'; opt.skipIe=true;
                if(j==5)
                    npgTValpha_b1_E100_cont{i,j}=beamhardenSpline(Phi,Phit,Psi,Psit,y,initSig,opt);
                else
                    opt.Ie=npgTValpha_b1_E100_cont{i,j+1}.Ie;
                    npgTValpha_b1_E100_cont{i,j}=beamhardenSpline(Phi,Phit,Psi,Psit,y,...
                        npgTValpha_b1_E100_cont{i,j+1}.alpha,opt);
                end

            end

            continue;
             
            % unknown ι(κ), NPG-LBFGSB
            for j=[5:-1:2]
                fprintf('%s, i=%d, j=%d\n','NPG-AS',i,j);

                if(i==3 && (j==3 || j==4))
                    opt=OPT; opt.u=10^(j-3)*u(i); opt.alphaStep='NPG'; opt.proximal='tviso'; opt.restart=false; opt.adaptiveStep=false;
                    npgTV_b1_norestart_noAdaptiveStep{i,j}=beamhardenSpline(Phi,Phit,Psi,Psit,y,initSig,opt);
                    save(filename);
                end
                continue;

                if(i==3 && (j==3 || j==4))
                    opt=OPT; opt.u=10^(j-3)*u(i); opt.alphaStep='NPG'; opt.proximal='tviso'; opt.restart=false;
                    npgTV_b1_norestart{i,j}=beamhardenSpline(Phi,Phit,Psi,Psit,y,initSig,opt);
                    save(filename);
                end
                continue;

                opt=OPT; opt.u=10^(j-3)*u(i); opt.alphaStep='NPG'; opt.proximal='tviso';
                npgTV_b1{i,j}=beamhardenSpline(Phi,Phit,Psi,Psit,y,initSig,opt);

                opt=OPT; opt.u=10^(j-3)*u(i); opt.alphaStep='NPG'; opt.proximal='tviso'; opt.E=100;
                npgTV_b1_E100{i,j}=beamhardenSpline(Phi,Phit,Psi,Psit,y,initSig,opt);

                opt=OPT; opt.u=10^(j-3)*u(i); opt.alphaStep='NPG'; opt.proximal='tviso';
                if(j==5)
                    npgTV_b1_cont{i,j}=beamhardenSpline(Phi,Phit,Psi,Psit,y,initSig,opt);
                else
                    opt.Ie=npgTV_b1_cont{i,j+1}.Ie;
                    npgTV_b1_cont{i,j}=beamhardenSpline(Phi,Phit,Psi,Psit,y,...
                        npgTV_b1_cont{i,j+1}.alpha,opt);
                end
            end
            continue;

            % unknown ι(κ), PG-LBFGSB
            for j=5:-1:1
                if(i==3 && (j==3||j==4))
                    opt=OPT; opt.u=u(i)*10^(j-3); opt.proximal='tviso'; opt.alphaStep='PG';
                    pgTV_b1{i,j}=BHC.main(Phi,Phit,Psi,Psit,y,initSig,opt);
                    save(filename);
                end
            end
            continue

            % known ι(κ), linearization
            opt=OPT; opt.E=100;
            kappa=logspace(-floor(opt.E/2)/(opt.E-1)*3,...
                floor(opt.E/2-0.5)/(opt.E-1)*3,opt.E);
            q=kappa(2)/kappa(1);
            polymodel=Spline(opt.spectBasis,[kappa(1)/q; kappa(:); kappa(end)*q]);
            polyIout = polymodel.polyIout; clear('q');
            [opt.upkappa,opt.upiota]=getUpiota(opt.epsilon,opt.kappa,opt.iota);
            trueIe=interp1(log(opt.upkappa), opt.upiota ,log(kappa(:)),'spline');
            trueIe=max(0,trueIe);
            s=linspace(min(y(:))/10,max(y(:))*10,10000);
            yy=interp1(-log(polyIout(s,trueIe)),s,y,'spline');

            fprintf('%s, i=%d,\n','Linearized Filtered Backprojection',i);
            linFbp{i}.img=FBP(yy);
            linFbp{i}.alpha=linFbp{i}.img(opt.mask~=0);
            linFbp{i}.RMSE=1-(innerProd(linFbp{i}.alpha,opt.trueAlpha)^2)/sqrNorm(opt.trueAlpha)/sqrNorm(linFbp{i}.alpha);
            fprintf('linFbp RMSE=%g\n',linFbp{i}.RMSE);
            initSig = maskFunc(FBP(yy),opt.mask~=0);

            if(i==3)
                for j=3
                    opt.u=10^(j-3)*u(i)*max(abs(Psit(Phit(yy)))); opt.proximal='tviso';
                    opt.noiseType='gaussian';
                    linNpgTV_E100{i,j}=Wrapper.NPG(Phi,Phit,Psi,Psit,yy,initSig,opt);
                end
                save(filename);
            end

            % unknown ι(κ), NPG-LBFGSB without sparsity constraints
            opt=OPT;
            opt.u=0; j=1; opt.alphaStep='NPG'; opt.proximal='nonneg';
            for k=1:5
                [y,Phi,Phit,Psi,Psit,opt,FBP]=loadYang(opt,k-1);
                npgTV_b1_u0{i,j,k}=beamhardenSpline(Phi,Phit,Psi,Psit,y,initSig,opt);
            end

            if(i==3)
                opt.maxItr=500; % this one works the best, see npgTV_b1_u0
                npgTV_b1_u0_i3=beamhardenSpline(Phi,Phit,Psi,Psit,y,initSig,opt);
                opt=OPT;
                save(filename);
            end

            % known ι(κ), NPG
            for j=2
                fprintf('%s, i=%d, j=%d\n','NPG skipIe',i,j);
                opt=OPT; opt.u=10^(j-3)*u(i); opt.E=100;
                opt.alphaStep='NPG'; opt.proximal='tviso'; opt.skipIe=true;
                if(j==5)
                    npgTValpha_b1_E100_cont{i,j}=beamhardenSpline(Phi,Phit,Psi,Psit,y,initSig,opt);
                else
                    opt.Ie=npgTValpha_b1_E100_cont{i,j+1}.Ie;
                    npgTValpha_b1_E100_cont{i,j}=beamhardenSpline(Phi,Phit,Psi,Psit,y,...
                        npgTValpha_b1_E100_cont{i,j+1}.alpha,opt);
                end

                continue;

            end

             
            % linear sparse model
            for j=1:5
                opt.u=10^(j-3)*u(i)*max(abs(Psit(Phit(yy))));
                opt.proximal='tvl1';
                npgTV{i,j}=Wrapper.NPG(Phi,Phit,Psi,Psit,y,initSig,opt);
                opt.proximal='wvltADMM';
                npgWV{i,j}=Wrapper.NPG(Phi,Phit,Psi,Psit,y,initSig,opt);
            end
        end

    case 'plot'
        load([mfilename '.mat']);

        prjFull = [32, 40, 60, 80, 100, 120, 180, 360];

        linFbpRMSE    = Cell.getField(       linFbp,'RMSE');
        fbpRMSE       = Cell.getField(          fbp,'RMSE');
        npgTVb1RMSE   = Cell.getField(     npgTV_b1,'RMSE');
        for i=1:length(prjFull)
            npgTVb1u0RMSE(i,1) = min(npgTV_b1_u0{i}.RMSE);
        end
        %npgTVb1u0RMSE   = Cell.getField(     npgTV_b1_u0,'RMSE');
        
        npgTVb1contRMSE = Cell.getField(     npgTV_b1_cont,'RMSE');
        npgTVb1E100RMSE = Cell.getField(     npgTV_b1_E100,'RMSE');

        linNpgRMSE    = Cell.getField(     linNpgTV,'RMSE');
        npgTValphaRMSE= Cell.getField(npgTValpha_b1,'RMSE');
        npgTValphaE100RMSE= Cell.getField(npgTValpha_b1_E100_cont,'RMSE');

%       npgTVRMSE     = Cell.getField(        npgTV,'RMSE');
%       npgWVRMSE     = Cell.getField(        npgWV,'RMSE');
         
        figure;
        semilogy(prjFull,              linFbpRMSE*100,'r-*'); hold on;
        semilogy(prjFull,                 fbpRMSE*100,'b-o');
        semilogy(prjFull,min(   npgTVb1RMSE,[],2)*100,'g-.');
        semilogy(prjFull,min(    linNpgRMSE,[],2)*100,'c-<');
        semilogy(prjFull,min(npgTValphaRMSE,[],2)*100,'k-s');
        semilogy(prjFull,min(npgTValphaE100RMSE,[],2)*100,'r->');
        semilogy(prjFull,min(npgTVb1contRMSE,[],2)*100,'c-h');
        semilogy(prjFull,min(npgTVb1E100RMSE,[],2)*100,'c-h');
        semilogy(prjFull,min(npgTVb1u0RMSE,[],2)*100,'g:+');
        xlabel('# fan-beam projections from 0-359^\circ'); ylabel('RMSE/%');
        legend('linearized FBP', 'FBP', 'NPG\_TV', 'linearized NPG', 'NPG\_TV (known \iota)',...
            'NPG (known \iota 100)','NPG-BFGS-cont','NPG-BFGS-100','NPG-BFGS-u0');

        forSave=[prjFull(:)';
        100*           linFbpRMSE(:)';
        100*              fbpRMSE(:)';
        100*min(   npgTVb1RMSE,[],2)';
        100*min(    linNpgRMSE,[],2)';
        100*min(npgTValphaRMSE,[],2)';
        100*min(npgTVb1contRMSE,[],2)';
        100*min(npgTValphaE100RMSE,[],2)';
        100*min(npgTVb1u0RMSE,[],2)'; ]';
        save('rmse_prj_yang.data','forSave','-ascii');

        keyboard

        prjIdx=3; col=250; h=figure; forSave=[];

        img=showImgMask(          fbp{prjIdx     }.alpha,opt.mask); maxImg=max(img(:));
        img=showImgMask(          fbp{prjIdx     }.alpha,opt.mask); maxImg=normalize(img(:),opt.trueImg);
        figure; showImg(img,0,maxImg); saveas(gcf,       'fbp_yang.eps','psc2'); imwrite(img/maxImg,       'fbp_yang.png');
        fprintf('FBP RMSE=%e\n',fbpRMSE(prjIdx));
        figure(h); plot(img(:,col),'b-'); hold on; forSave=[forSave, img(:,col)];

        img=showImgMask(       linFbp{prjIdx     }.alpha,opt.mask); maxImg=max(img(:));
        img=showImgMask(       linFbp{prjIdx     }.alpha,opt.mask); maxImg=normalize(img(:),opt.trueImg);
        figure; showImg(img,0,maxImg); saveas(gcf,    'linFBP_yang.eps','psc2'); imwrite(img/maxImg,    'linFBP_yang.png');
        fprintf('linFBP RMSE=%e\n',linFbpRMSE(prjIdx));
        figure(h); plot(img(:,col),'r-'); hold on; forSave=[forSave, img(:,col)];

        rmse=linNpgRMSE; aIdx=find(min(rmse(prjIdx,:))==rmse(prjIdx,:)); u = 10.^[-5  -5   -5   -5   -5   -5 -5 -5];
        img=showImgMask(     linNpgTV{prjIdx,aIdx}.alpha,opt.mask); maxImg=normalize(img(:),opt.trueImg);
        figure; showImg(img,0,maxImg); saveas(gcf,  'linNPGTV_yang.eps','psc2'); imwrite(img/maxImg,  'linNPGTV_yang.png');
        fprintf('a for linNPGTV is %e and u=%g, RMSE=%g\n',10^(aIdx-3)*u(prjIdx),linNpgTV{prjIdx,aIdx}.opt.u,rmse(prjIdx,aIdx));
        figure(h); plot(img(:,col),'c-'); forSave=[forSave, img(:,col)];

        rmse=npgTValphaRMSE; aIdx=find(min(rmse(prjIdx,:))==rmse(prjIdx,:));
        img=showImgMask(npgTValpha_b1{prjIdx,aIdx}.alpha,opt.mask); maxImg=normalize(img(:),opt.trueImg);
        figure; showImg(img,0,maxImg); saveas(gcf,'npgTValpha_yang.eps','psc2'); imwrite(img/maxImg,'npgTValpha_yang.png');
        fprintf('u for npgTValpha_b1 is %e, RMSE=%g\n',10^(aIdx-3)*u(prjIdx),rmse(prjIdx,aIdx));
        figure(h); plot(img(:,col),'k--'); forSave=[forSave, img(:,col)];

        rmse=npgTVb1RMSE; aIdx=find(min(rmse(prjIdx,:))==rmse(prjIdx,:));
        img=showImgMask(     npgTV_b1{prjIdx,aIdx}.alpha,opt.mask); maxImg=normalize(img(:),opt.trueImg);
        figure; showImg(img,0,maxImg); saveas(gcf,     'npgTV_yang.eps','psc2'); imwrite(img/maxImg,     'npgTV_yang.png');
        fprintf('u for NPGTV is %e, RMSE=%g\n',10^(aIdx-3)*u(prjIdx),rmse(prjIdx,aIdx));
        figure(h); plot(img(:,col),'g-.'); forSave=[forSave, img(:,col)];

        rmse=npgTValphaE100RMSE; aIdx=find(min(rmse(prjIdx,:))==rmse(prjIdx,:));
        img=showImgMask(     npgTValpha_b1_E100_cont{prjIdx,aIdx}.alpha,opt.mask); maxImg=normalize(img(:),opt.trueImg);
        figure; showImg(img,0,maxImg);  imwrite(img/maxImg,     'npgTValpha100_yang.png');
        fprintf('u for NPGTValpha100 is %e, RMSE=%g\n',10^(aIdx-3)*u(prjIdx),rmse(prjIdx,aIdx));
        figure(h); plot(img(:,col),'k-.'); forSave=[forSave, img(:,col)];

        rmse=npgTVb1contRMSE; aIdx=find(min(rmse(prjIdx,:))==rmse(prjIdx,:));
        img=showImgMask(     npgTV_b1_cont{prjIdx,aIdx}.alpha,opt.mask); maxImg=normalize(img(:),opt.trueImg);
        figure; showImg(img,0,maxImg);  imwrite(img/maxImg,     'npgTVcont_yang.png');
        fprintf('u for NPGTVcont is %e, RMSE=%g\n',10^(aIdx-3)*u(prjIdx),rmse(prjIdx,aIdx));
        figure(h); plot(img(:,col),'c--'); forSave=[forSave, img(:,col)];

        rmse=npgTVb1u0RMSE;
        img=showImgMask(     npgTV_b1_u0{prjIdx}.alpha,opt.mask); maxImg=normalize(img(:),opt.trueImg);
        figure; showImg(img,0,maxImg);  imwrite(img/maxImg,     'npgTVb1u0_full_yang.png');
        fprintf('u for NPGTVcont is %e, best RMSE=%g, ending RMSE=%g\n',0,rmse(prjIdx),npgTV_b1_u0{prjIdx}.RMSE(end));
        figure(h); plot(img(:,col),'c--'); forSave=[forSave, img(:,col)];

        rmse=npgTV_b1_u0_i3.RMSE(end);
        img=showImgMask(     npgTV_b1_u0_i3.alpha,opt.mask); maxImg=normalize(img(:),opt.trueImg);
        figure; showImg(img,0,maxImg);  imwrite(img/maxImg,     'npgTVb1u0_best_yang.png');
        fprintf('u for NPGTVcont is %e, RMSE=%g\n',0,rmse);
        figure(h); plot(img(:,col),'c--'); forSave=[forSave, img(:,col)];

        img=opt.trueImg; maxImg=normalize(img(:),opt.trueImg); imwrite(img/maxImg,     'yang.png');

        legend('FBP', 'linearized FBP', 'linearized NPG', 'NPG\_TV (known \iota)', 'NPG\_TV','NPG 100 cont', 'NPG-BFGS cont');
        save('profile_yang.data','forSave','-ascii');

        forSave=[]; t=0; h1=figure; h2=figure;
        a1=npgTV_b1_u0{prjIdx};
        t=t+1; temp=a1.time(:); forSave(1:length(temp),t)=temp;
        t=t+1; temp=a1.cost(:); forSave(1:length(temp),t)=temp; figure(h1); semilogy(temp,'r'); hold on;
        t=t+1; temp=a1.RMSE(:); forSave(1:length(temp),t)=temp; figure(h2); semilogy(temp,'r'); hold on;
        rmse=linNpgRMSE; aIdx=find(min(rmse(prjIdx,:))==rmse(prjIdx,:)); a1=linNpgTV_E100{prjIdx,aIdx};
        t=t+1; temp=a1.time(:); forSave(1:length(temp),t)=temp;
        t=t+1; temp=a1.cost(:); forSave(1:length(temp),t)=temp; figure(h1); semilogy(temp,'g'); disp([prjIdx,aIdx]);
        t=t+1; temp=a1.RMSE(:); forSave(1:length(temp),t)=temp; figure(h2); semilogy(temp,'g');
        rmse=npgTValphaE100RMSE; aIdx=find(min(rmse(prjIdx,:))==rmse(prjIdx,:));  a1=npgTValpha_b1_E100{prjIdx,aIdx};
        t=t+1; temp=a1.time(:); forSave(1:length(temp),t)=temp;
        t=t+1; temp=a1.cost(:); forSave(1:length(temp),t)=temp; figure(h1); semilogy(temp,'b'); disp([prjIdx,aIdx]);
        t=t+1; temp=a1.RMSE(:); forSave(1:length(temp),t)=temp; figure(h2); semilogy(temp,'b');
        rmse=npgTVb1RMSE; aIdx=find(min(rmse(prjIdx,:))==rmse(prjIdx,:));  a1=npgTV_b1{prjIdx,aIdx};
        t=t+1; temp=a1.time(:); forSave(1:length(temp),t)=temp;
        t=t+1; temp=a1.cost(:); forSave(1:length(temp),t)=temp; figure(h1); semilogy(temp,'r--'); disp([prjIdx,aIdx]);
        t=t+1; temp=a1.RMSE(:); forSave(1:length(temp),t)=temp; figure(h2); semilogy(temp,'r--');
        a1=pgTV_b1{prjIdx,aIdx};
        t=t+1; temp=a1.time(:); forSave(1:length(temp),t)=temp;
        t=t+1; temp=a1.cost(:); forSave(1:length(temp),t)=temp; figure(h1); semilogy(temp,'r--'); disp([prjIdx,aIdx]);
        t=t+1; temp=a1.RMSE(:); forSave(1:length(temp),t)=temp; figure(h2); semilogy(temp,'r--');
        figure(h1); legend('npgTV\_b1\_u0','linNpgTV','npgTValpha\_b1\_E100','npgTV\_b1','pgTV\_b1'); title('objective vs itr');
        figure(h2); legend('npgTV\_b1\_u0','linNpgTV','npgTValpha\_b1\_E100','npgTV\_b1','pgTV\_b1'); title('rmse vs itr');
        save('yangTrace.data','forSave','-ascii');

        keyboard

        prjIdx=3; col=250; forSave=[]; clear('opt');
        rmse=npgTVb1RMSE;    aIdx=find(min(rmse(prjIdx,:))==rmse(prjIdx,:)); a1=npgTV_b1{prjIdx,aIdx};
        rmse=npgTValphaRMSE; aIdx=find(min(rmse(prjIdx,:))==rmse(prjIdx,:)); a2=npgTValpha_b1{prjIdx,aIdx};

        [y,Phi,Phit,Psi,Psit,~,FBP]=loadYang(a1.opt);

        q=a1.kappa(2)/a1.kappa(1);
        polymodel=Spline(a1.opt.spectBasis,[a1.kappa(1)/q; a1.kappa(:); a1.kappa(end)*q]);
        polyIout = polymodel.polyIout;

        PhiAlpha=Phi(a1.alpha);
        PhiFbp=Phi(fbp{prjIdx}.alpha);

        s=linspace(min(PhiAlpha),max(PhiAlpha),100);
        idx=randi(length(PhiAlpha),1000,1);

        figure;
        plot(PhiAlpha(idx),y(idx),'.'); hold on;
        plot(PhiFbp(idx),y(idx),'g.');
        plot(s,-log(polyIout(s,a1.Ie)),'r-');
        legend('NPG-BFGS reconstruction', 'FBP reconstruction', 'fitted curve by NPG-BFGS');
        xlabel('\Phi\alpha');
        ylabel('I^{out}=-ln[ \int \iota(\kappa) exp( -\kappa\Phi\alpha ) d\kappa  ]');

        forSave=[PhiAlpha(idx),y(idx)];
        save('test1.data','forSave','-ascii');
        forSave=[PhiFbp(idx),y(idx)];
        save('test2.data','forSave','-ascii');
        forSave=[s(:), -log(polyIout(s,a1.Ie))];
        save('test3.data','forSave','-ascii');

        !for i in `seq 1 3`; do echo "" >> test$i.data; done
        !for i in `seq 1 3`; do echo "" >> test$i.data; done
        !cat test[1-3].data > linearization_yang.data
        !rm test[1-3].data

        [upkappa,upiota]=getUpiota(a1.opt.epsilon,a1.opt.kappa,a1.opt.iota);
        upkappa(3)=[]; upiota(3)=[];
        q=upkappa(2)/upkappa(1);
        N=40; offset=30; overlap=3;
        %upkappa=[(q.^(-N:-1)')*upkappa(1); upkappa(:)];
        upiota=upiota(:);
        upiota1=[upiota(end-offset:-1:end-offset-N-overlap+2);  upiota(overlap:end)*0];
        upiota2=[upiota(end-offset:-1:end-offset-N+1)*0;  upiota(1:end)];
        %upiota=upiota2+upiota1;
        forSave=[upkappa(:) upiota(:)];
        save('upiota.data','forSave','-ascii');
        sampledUpkappa=logspace(log10(0.03), log10(100), 50);
        anchor=0.243;
        temp=abs(sampledUpkappa-anchor);
        temp=sampledUpkappa(temp==min(temp));
        sampledUpkappa=sampledUpkappa*anchor/temp;
        sampledUpiota=interp1(log(a1.opt.upkappa), a1.opt.upiota ,log(sampledUpkappa(:)),'linear');
        sampledUpiota=max(sampledUpiota(:),0);
        figure; semilogx(upkappa,upiota); hold on;
        semilogx(sampledUpkappa,sampledUpiota,'*r');
        forSave=[sampledUpkappa(:) sampledUpiota(:)];
        save('sampledupiota.data','forSave','-ascii');

        idx= find((PhiAlpha>2.9) & (PhiAlpha<3.1));
        figure; hist(exp(-y(idx)),100);

        switch lower(a1.opt.noiseType)
            case lower('Gaussian')
                IeStepFunc = @(AA,III) gaussLI(exp(-y),polyIout(Phi(AA),[]),III);
            case lower('Poisson')
                IeStepFunc = @(AA,III) poissLI(exp(-y),polyIout(Phi(AA),[]),III);
        end

        [IeStepFunc(a1.alpha,a1.Ie), IeStepFunc(a1.alpha*(a1.alpha'*a2.alpha)/sqrNorm(a1.alpha),a2.Ie);
        IeStepFunc(a2.alpha*innerProd(a1.alpha,a2.alpha)/sqrNorm(a2.alpha),a1.Ie), IeStepFunc(a2.alpha,a2.Ie)]

        IeStepFunc(a1.opt.trueAlpha*innerProd(a1.opt.trueAlpha,a1.alpha)/sqrNorm(a1.opt.trueAlpha),a1.Ie)
        IeStepFunc(a1.opt.trueAlpha*innerProd(a1.opt.trueAlpha,a2.alpha)/sqrNorm(a1.opt.trueAlpha),a2.Ie)

        keyboard
        paperDir = './';
        %system(['mv effectiveCenterB.data ' paperDir]);
    end
end

function data=normalize(a,mask)
    if(~exist('mask','var'))
        mask=opt.trueImg;
    end
    data=mean(a(mask>0))*1.4;
    a=reshape(a,sqrt(length(a)),[]);

    i=256;
    figure; subplot(2,1,1); plot(sort(a(:),'descend')); hold on; plot(ones(10000,1)*data,'r');
    subplot(2,1,2); plot(a(:,i)); hold on; plot(a(:,i)*0+data,'r');
end

