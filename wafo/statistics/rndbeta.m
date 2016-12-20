function R = rndbeta(varargin)
%RNDBETA  Random matrices from a Beta distribution
%
% CALL:  R =rndbeta(a,b,sz)
%        R =rndbeta(phat,sz)
%
%       R = matrix of random numbers
%    a, b = parameters
%    phat = Distribution parameter struct
%             as returned from FITBETA.  
%      sz = size(R)    (Default size(a))
%            sz can be a comma separated list or a vector 
%            giving the size of R (see zeros for options)
% 
%  The random numbers are generated by 3 different methods depending on the
%  parameter values:
%  -Cheng's algortihm BB	for      :             1 < min(a,b)
%  -Joehnk's algorithm for         : max(a,b) < 0.5
%  -Atkinson's switching algorithm : min(a,b) <= 1 <= max(a,b), and 
%                               	0.5<= max_ab < 1, 
% 
% Example:
%    par = {1,1};
%    X = rndbeta(par{:},1000,1);
%    moments = [mean(X) var(X),skew(X),kurt(X)];   % Estimated mean and variance
%    [mom{1:4}] = mombeta(par{:});       % True mean and variance
%
% See also pdfbeta, cdfbeta, rndbeta, fitbeta, mombeta


%  *  Copyright (C) 2000	2007 Kevin Karplus, Per A. Brodtkorb
%  *
%  *  This sofware is free software; you can redistribute it and/or
%  *  modify it under the terms of the GNU Lesser General Public
%  *  License as published by the Free Software Foundation; 
%  *  version 2.1 of the License.
%  *
%  *  This library is distributed in the hope that it will be useful,
%  *  but WITHOUT ANY WARRANTY; without even the implied warranty of
%  *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%  *  Lesser General Public License for more details.
%  *
%  *  See http://www.gnu.org/copyleft/lesser.html for the license details,
%  *  or write to the Free Software Foundation, Inc., 59 Temple Place, Suite
%  *  330, Boston, MA 02111-1307 USA
%  */
% 

% This code is written in  matlab by Per A Brodtkorb, translated from  the 
% /* gen_beta c-code written by Kevin Karplus  2-6 Nov 2000
%  *
%  * Some inspiration was taken from genbet in ranlib.c, which was
%  * written by Barry Brown and James Lovato. 
%  * Their code was full of completely unnecessary goto statements,
%  * since it was generated by a Fortran-to-c conversion.
%  * They also did not provide for generating interleaved streams from
%  * multiple beta distributions, and one of their cases did not seem to
%  * work correctly after cleaning up the code.
%  * After failing to fix their code, I started over from scratch.
%  *
%  * The current version uses 3 different beta generators, based on the
%  * parameter values.
%  * This choice of generators was based in part on the information in
%  * Dagpunar's book "Principles of Random Variate Generation",
%  * and partly on Chapter 21 of the documentation for the Numerical
%  * Analysis Group's software: routine nag_rand_beta.
%  * www.nag.com/numeric/fbfn/fn/Ctwentyone/Ctwentyone_txt.html
%  *
%  * I could not get any of the implementations of Cheng's Algorithm BC to
%  * produce the right moments, so I stopped using it, and used Atkinson's
%  * switching method for 0.5<= max_ab < 1 instead.  The bugs were
%  * probably in my translation of the method, not in the method itself,
%  * as I was working exclusively from secondary sources.
%  * 
%  * The implementations finally chosen were selected more for
%  * robustness than absolute efficiency:
%  *	1 < min_ab , using Cheng's algortihm BB
%  *	min_ab <= 1 <= max_ab, using Atkinson's switching algorithm
%  * 	max_ab < 0.5,  using Joehnk's algorithm
%  *	0.5<= max_ab < 1, using Atkinson's switching algorithm
%  */

%References
%      R. C. H. Cheng
%      Generating Beta Variates with Nonintegral Shape Parameters
%      Communications of the ACM, 21:317-322  (1978)
%      (Algorithms BB and BC)
%      
%      Atkinson, A. C. 
%      A family of switching algorithms for the computer generation of
%      beta random variables.
%      Biometrika 66:141-145. (1979)
%      
%      Joehnk, M.D.
%      Erzeugung von Betaverteilten und Param[1]verteilten Zufallszahlen.
%      Metrika, 8:5-15. (1964)
%      
%      Cited in 
%      Dagpunar, John.
%      Principles of Random Variate Generation.
%      Oxford University Press, 1988.
% */


error(nargchk(1,inf,nargin))
Np = 2;
options = []; % struct; % default options
[params,options,rndsize] = parsestatsinput(Np,options,varargin{:});
% if numel(options)>1
%   error('Multidimensional struct of distribution parameter not allowed!')
% end

[a,b] = deal(params{:});

if isempty(rndsize),
  [csize] = comnsize(a,b);
else
  [csize] = comnsize(a,b,zeros(rndsize{:}));
end 
if any(isnan(csize))
  error('a and b must be a scalar or of corresponding size as given by m and n.');
end

%R = invbeta(rand(csize),a,b);
%return


 
a(a<=0) = nan;
b(b<=0) = nan;
 
 
 
 max_ab = max( a, b );
 min_ab = min( a, b );
 if isscalar(a) && isscalar(b)
   if max_ab < 0.5
     R = alg_joehnk(a,b,csize);
   elseif min_ab > 1
     R = alg_cheng(a,b,csize);
   else
     % min_ab < 1 && max_ab > 1
     R = alg_atkinson(a,b,csize);
   end
 else
   R =zeros(csize);
   if isscalar(a), a = a(ones(csize));end
   if isscalar(b), b = b(ones(csize));end
   r1 = find(max_ab < 0.5);
   if any(r1)
     R(r1) = alg_joehnk(a(r1),b(r1),size(r1));
   end
   r2 = find(min_ab > 1);
   if any(r2)
     R(r2) = alg_cheng(a(r2),b(r2),size(r2));
   end
   r3 = find(min_ab <= 1 & max_ab > 1 | 0.5<= max_ab & max_ab<=1);
   if any(r3)
     R(r3) = alg_atkinson(a(r3),b(r3),size(r3));
   end
 end
%  m = 0;
%  n = 1;
%  R = m + (n-m) * R;
  
function R = alg_joehnk(a,b,csize)
  % Use Joehnk's algorithm for max(a,b)<0.5
  %
 %  Use logv and logw, rather than v and w, to avoid
 % 	  floating-point underflow with very small a or b values.
 % 	 
    
 scalarAB = isscalar(a) || isscalar(b);
   
 logv = log(rand(csize))./a;
 logw = log(rand(csize))./b;
 sgn = 2*(logv>logw)-1;
 log_sum = max(logv,logw)+log1p(+exp(sgn.*(logw-logv)));
 R = exp(logv-log_sum);   
 left = find(log_sum>0);
 if ~scalarAB
   a = a(left);
   b = b(left);
 end
 while any(left(:));
   sz = size(left);
   logv = log(rand(sz))./a;
   logw = log(rand(sz))./b;
   sgn = 2*(logv>logw)-1;
   log_sum = max(logv,logw)+log1p(+exp(sgn.*(logw-logv)));
   accept = ~(log_sum>0);
   if any(accept(:))
     R(left(accept)) = exp(logv(accept)-log_sum(accept));
     if ~scalarAB
       a(accept)=[];
       b(accept)=[];
     end
     left(accept) =[];
   end
 end % while
   
 % end function alg_joenck
   
   function R = alg_cheng(a,b,csize)
     % Chengs Algorithm BB
     
     
     min_ab = min(a,b);
     max_ab = max(a,b);
   
     sum_ab = a + b;
     isscalarAB = isscalar(sum_ab);
     
     lambda = sqrt((sum_ab-2)./(2.*a.*b-sum_ab));
     c = min_ab+1./lambda;
      
     %lambda = gen->param[0];
     %c = gen->param[1];
    
     R = zeros(csize);
     left    = R;
     
     left(:) = 1:numel(left);
     ok = isfinite(sum_ab);
     if any(~ok)
       if isscalarAB
         R(:) = nan;
         left = [];
       else
         R(~ok) = nan;
         left(~ok) = [];
       end
     end
       
     
     while any(left(:))
       sz = size(left);
       r = rand(sz);
       w = rand(sz);
       z = r.*r.*w;
       
       v = lambda.*log(r./(1.0-r));
       w = min_ab.*exp(v);
       
       r = c.*v-1.38629436112;
       s = min_ab+r-w;
       accept = ~(s+2.609438 < 5*z) | ~(r+sum_ab.*log(sum_ab./(max_ab+w)) < log(z));
       if any(accept(:)),
         if isscalarAB
           if a == min_ab
             R(left(accept) ) = w(accept)./(max_ab+w(accept));
           else
             R(left(accept)) = max_ab./(max_ab+w(accept));
           end
         else
           ais =  a == min_ab;
           R(left(accept)) = (ais.*w(accept)+ (~ais).*max_ab(accept))./(max_ab(accept)+w(accept));
           
           a(accept) = [];
           c(accept) = [];
           lambda(accept) = [];
           min_ab(accept) = [];
           max_ab(accept) = [];
           sum_ab(accept) = [];
         end
         left(accept) = [];
       end
     end
     % end alg_cheng BB algorithm
   
  
 
     function  R = alg_atkinson(a,b,csize)
%* use Atkinson's switching method, as
%     	 * described in Dagpunar's book
% 	 * p=min_ab, q=max_ab
% 	 * t stored as gen->param[0], r as gen->param[1]
% 	 */

    
scalarAB = isscalar(a) || isscalar(b);
max_ab = max( a, b );
min_ab = min( a, b );
if scalarAB
if (max_ab > 1.0)
  t = (1-min_ab)./(1+max_ab - min_ab);
  r = max_ab .* t ./( max_ab .* t +min_ab.*(1-t).^max_ab);
    
else
  %  /* use Atkinson's switching algorithm 0.5 <= max_ab <= 1.0
  
  if (min_ab == 1.0)
    r = 0.5;
    t = 0.5;
  else
	  t = 1./(1+sqrt(max_ab.*(1-max_ab)./ (min_ab.*(1-min_ab))));
    r = max_ab .* t./(max_ab .* t + min_ab .* (1-t));
  end
end
if max_ab>=1
  scalew = 1;
else
  scalew = (1-t);
end
else
end
   
   
 
  R = zeros(csize);     
  w = R;
	left = R;
  left(:) = 1:numel(R);
  accept = logical(R);
  while any(left(:))
    sz = size(left);
    u1 = rand(sz);
    u2 = rand(sz);
    
    sml = u1<r;
    
    if scalarAB
       w(sml) = t*(u1(sml)/r).^(1./min_ab);   
       accept(sml) = ~(log(u2(sml)) >= (max_ab -1)*log((1-w(sml))/scalew));
       
       w(~sml) = 1- (1-t)*((1-u1(~sml))/(1-r)).^(1./max_ab);
       accept(~sml) = ~(log(u2(~sml)) >= (min_ab -1) * log((w(~sml))/t));
    else
      if any(sml)
        w =  t.*(u1./r).^(1./min_ab);
        accept =  ~(log(u2) >= (max_ab -1).*log((1-w)./scalew));
      end
      if any(~sml)
         w1 = 1- (1-t).*((1-u1)./(1-r)).^(1./max_ab);
         w(~sml) = w1(~sml);
         accept(~sml) = ~(log(u2(~sml)) >= (min_ab(~sml) -1) .* log(w(~sml)./t(~sml)));
      end
    end
    if any(accept)
      if scalarAB
        if a== min_ab
          R(left(accept))= w(accept);
        else
          R(left(accept))= 1-w(accept);
        end
      else
        ais =  a == min_ab;
        R(left(accept)) = ~ais +(2*(ais)-1).* w(accept);
        min_ab(accept) = [];
        max_ab(accept) = [];
        t(accept) = [];
        r(accept) =[];
        scalew(accept) = [];
      end
      w(accept) = [];
      left(accept) = [];
      accept(accept) = [];
    end
  end % while
	

   