function SpaRSA(obj)
    pp=0; obj.converged = false; obj.warned = false; needBreak = false;
    while(pp<obj.maxStepNum)
        obj.p = obj.p + 1;
        pp=pp+1;
        si = obj.Psit(obj.alpha);

        if(obj.p==1)
            [oldCost,grad,hessian] = obj.func(obj.alpha);
            deltaNormAlpha=grad'*grad;
            obj.t = hessian(grad,2)/deltaNormAlpha;
        else
            [oldCost,grad] = obj.func(obj.alpha);
            obj.t = abs((grad-obj.preG)'*(obj.alpha-obj.preAlpha)/...
                ((obj.alpha-obj.preAlpha)'*(obj.alpha-obj.preAlpha)));
        end
        obj.oldCost = [oldCost+obj.u*sum(abs(si)); obj.oldCost(1:obj.M-1)];
        dsi = obj.Psit(grad);

        % start of line Search
        ppp=0;
        while(~obj.converged && ~needBreak)
            ppp=ppp+1;
            wi=si-dsi/obj.t;
            newSi=Methods.softThresh(wi,obj.u/obj.t);
            newX = obj.Psi(newSi);
            difAlpha = (newX-obj.alpha)'*(newX-obj.alpha);

            newCost=obj.func(newX);
            obj.fVal(3) = sum(abs(newSi));
            newCost = newCost+obj.u*obj.fVal(3);

            % the following is the core of SpaRSA method
            if((newCost <= max(obj.oldCost) - obj.sigma*obj.t/2*difAlpha)...
                    || (ppp>10))
                break;
            else
                if(ppp>10)
                    warning('exit iterations for higher convergence criteria: %g\n',difAlpha);
                    obj.warned = true;
                    needBreak = true;
                else
                    obj.t=obj.t/obj.stepShrnk;
                end
            end
        end
        obj.preG = grad; obj.preAlpha = obj.alpha;
        obj.cost = newCost; obj.alpha = newX;
    end
end

