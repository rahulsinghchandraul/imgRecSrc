function [newdata,dist,img,center]=preprocessCTdata(data,thresh)
% this subroutine is used to find the center of the projection and the
% distance from the rotation center to X-ray source.
% Here, "data" is after taking the logarithm
    
    if(~exist('thresh','var')) thresh=0.5; end;

    mask=data>thresh;
    [N,M]=size(mask);
    for i=1:M
        g1(i,1) = find(mask(:,i),1);
        g2(i,1) = find(mask(:,i),1,'last');
    end
    center=(mean(g1)+mean(g2))/2;
    figure; showImg(data);
    figure; showImg(data); hold on; plot(g1,'r'); plot(g2,'r');
    drawnow;

    gl=g2-center; g2=g1-center; g1=gl; clear 'gl';
    G1=fft(g1); G2=fft(g2); gg=ifft(conj(G1).*(G2));
    dd(1)=mean(g1)/tan((find(gg==min(gg),1)-M/2)/M*2*pi);
    dd(2)=max(g1)/tan(...
        mod(find(g2==min(g2),1)-find(g1==max(g1),1)+M/2,M)*2*pi/M );
    dd(3)=min(g1)/tan(...
        mod(find(g2==max(g2),1)-find(g1==min(g1),1)+M/2,M)*2*pi/M );

    theta=(0:M-1)*2*pi/M; theta=theta(:);
    gg2=@(dddd) interp1([theta; theta+2*pi], [g2; g2],...
        theta+2*atan(  g1/dddd  )+pi,'spline');
    objfunc=@(ddd) norm(g1+gg2(ddd));
    [dist,~,status]=fminsearch(objfunc,median(dd));
    if(status~=1) keyboard; end

    ddRange=round(dist)-100:round(dist)+100;
    cost=inf*ones(length(ddRange),1);
    for i=1:length(ddRange)
        cost(i)=norm(g1+gg2(ddRange(i)));
    end
    figure; plot(ddRange,cost); hold on; plot(dist,objfunc(dist),'r*');

    figure; subplot(2,1,1); plot(theta,g1,'r'); hold on;
    plot(theta,-gg2(dist),'b');
    subplot(2,1,2); plot(theta,g1+gg2(dist));

    band=min(min(center-2,N-1-center),max(g1)*1.2);
    for i=1:M
        newdata(:,i) = interp1((1:N), data(:,i), (center-band):(center+band+1),'linear');
    end

    img=ifanbeam(newdata(end:-1:1,:),dist,...
        'FanCoverage','cycle','FanRotationIncrement',1,...
        'FanSensorGeometry','line','FanSensorSpacing',1,...
        'OutputSize',length(newdata(:,1)));
    figure; showImg(img,0);

end
