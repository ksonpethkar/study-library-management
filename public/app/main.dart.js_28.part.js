((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,B,C={
dAg(){return new C.Du(null)},
Du:function Du(d){this.a=d},
aBz:function aBz(d){var _=this
_.w="all"
_.x=""
_.y=d
_.d=$
_.c=_.a=null},
bPn:function bPn(d,e,f,g,h,i,j,k,l,m,n){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h
_.f=i
_.r=j
_.w=k
_.x=l
_.y=m
_.z=n},
bPm:function bPm(d,e,f,g,h,i,j,k,l,m,n,o){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h
_.f=i
_.r=j
_.w=k
_.x=l
_.y=m
_.z=n
_.Q=o},
bPk:function bPk(){},
bPl:function bPl(d){this.a=d},
bPw:function bPw(d){this.a=d},
bPx:function bPx(d){this.a=d},
bPy:function bPy(d){this.a=d},
bPv:function bPv(d){this.a=d},
bPz:function bPz(d){this.a=d},
bPu:function bPu(d,e){this.a=d
this.b=e},
bPA:function bPA(d,e){this.a=d
this.b=e},
bPp:function bPp(){},
bPq:function bPq(){},
bPr:function bPr(d){this.a=d},
bPt:function bPt(){},
bPs:function bPs(d,e,f){this.a=d
this.b=e
this.c=f},
bPo:function bPo(d,e,f){this.a=d
this.b=e
this.c=f},
bPj:function bPj(d,e){this.a=d
this.b=e},
bPi:function bPi(d,e){this.a=d
this.b=e}},D,E
J=c[1]
A=c[0]
B=c[2]
C=a.updateHolder(c[13],C)
D=c[18]
E=c[19]
C.Du.prototype={
a7(){return new C.aBz(new A.aA(B.as,$.ax()))}}
C.aBz.prototype={
t(){var x=this.y
x.X$=$.ax()
x.Z$=0
this.aB()},
aru(d){d=d.toLowerCase()
if(d==="created"||d==="add")return"CREATED"
if(d==="deleted"||d==="remove")return"DELETED"
if(d==="updated"||d==="edit")return"UPDATED"
if(d==="restored")return"RESTORED"
if(d==="login")return"LOGIN"
if(d==="approved")return"APPROVED"
if(d==="rejected")return"REJECTED"
if(d==="voided")return"VOIDED"
if(d==="exported")return"BACKUP"
if(d==="imported")return"RESTORE"
return d.toUpperCase()},
a8p(d,e){d=d.toLowerCase()
if(d==="created"||d==="add"||d==="approved")return e?B.fI:B.cl
if(d==="deleted"||d==="remove"||d==="rejected"||d==="voided")return e?B.hK:B.fZ
if(d==="updated"||d==="edit")return e?B.ni:B.hg
if(d==="restored")return e?B.Re:B.Ri
if(d==="login")return e?B.oV:B.iJ
if(d==="exported"||d==="imported")return e?B.yB:B.Se
return e?B.c1:B.lG},
arv(d,e){var x=this.a8p(d,e)
return x.n(e?0.2:0.12)},
a8m(d){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i="amount",h="studentName",g=d.h(0,"action"),f=J.L(g==null?"":g).toLowerCase()
g=d.h(0,"entityType")
x=J.L(g==null?"":g).toLowerCase()
g=d.h(0,"entityName")
w=g==null?null:J.L(g)
g=y.y
v=g.b(d.h(0,"details"))?g.a(d.h(0,"details")):A.I(y.w,y.b)
if(x==="receipt"){g=v.h(0,"receiptNumber")
u=g==null?w:g
if(u==null)u=""
t=v.h(0,i)!=null?"\u20b9"+A.r(v.h(0,i)):""
if(f==="deleted"){g=A.r(J.eA(u)?u:"")
s=t.length!==0?"("+t+")":""
return B.d.q("Deleted Fee Receipt #"+g+" "+s)}if(f==="created"){g=A.r(J.eA(u)?u:"")
s=t.length!==0?"("+t+")":""
return B.d.q("Generated Fee Receipt #"+g+" "+s)}return B.d.q("Receipt #"+A.r(J.eA(u)?u:"")+" ("+f+")")}if(x==="payment"){g=v.h(0,i)
t=g==null?v.h(0,"deletedAmount"):g
if(t==null)t=""
r=J.L(t).length!==0?"\u20b9"+A.r(t):""
g=v.h(0,"event")
q=g==null?null:J.L(g)
if((q==null?f:q)==="payment_voided")return B.d.q("Voided Payment "+r)
if(f==="deleted")return B.d.q("Deleted Payment Record "+r)
if(f==="created")return B.d.q("Recorded Payment "+r)
return B.d.q("Payment Updated "+r)}if(x==="student"){g=w==null?v.h(0,"name"):w
p=g==null?v.h(0,h):g
if(p==null)p="Student"
if(f==="created")return"Enrolled Student: "+A.r(p)
if(f==="deleted")return"Moved Student to Recycle Bin: "+A.r(p)
if(f==="restored")return"Restored Student from Bin: "+A.r(p)
if(J.p(v.h(0,"seatAssigned"),!0))return"Assigned Seat to "+A.r(p)
return"Updated Student: "+A.r(p)}if(x==="seat"||x==="section"){g=w==null?v.h(0,"seatId"):w
o=g==null?v.h(0,"sectionName"):g
if(o==null)o=""
if(f==="updated")return"Updated Seat / Layout "+(J.eA(o)?"#"+A.r(o):"")
if(f==="created")return"Created Seat / Section "+A.r(J.eA(o)?o:"")
return B.d.q(f+" Seat "+A.r(o))}if(f==="login"){g=v.h(0,"email")
n=g==null?d.h(0,"userEmail"):g
return"Admin Login: "+A.r(n==null?"Admin":n)}if(x==="request"){m=w==null?v.h(0,h):w
if(m==null)m="Student"
if(f==="approved")return"Approved Admission for "+A.r(m)
if(f==="rejected")return"Rejected Admission for "+A.r(m)
return"Admission Request: "+A.r(m)+" ("+f+")"}if(f==="exported")return"Created Full System Backup"
if(f==="imported")return"Restored Data from Backup File"
g=d.h(0,"message")
l=g==null?null:J.L(g)
if(l!=null&&l.length!==0)return l
k=f.length!==0?f[0].toUpperCase()+B.d.bn(f,1):"Action"
j=x.length!==0?x[0].toUpperCase()+B.d.bn(x,1):""
g=w==null?"":w
return B.d.q(k+" "+j+" "+g)},
bsG(d,e){var x,w,v,u,t,s=this,r="dd MMMM yyyy, hh:mm:ss a",q={},p=A.G(d).ax.a===B.aw,o=e.h(0,"action"),n=J.L(o==null?"":o),m=s.a8p(n,p),l=s.arv(n,p),k=s.a8m(e),j=e.h(0,"timestamp")
q.a="Unknown date"
if(j instanceof A.dZ)q.a=A.aM(r,null).a9(A.eC(j.gbd()))
else if(typeof j=="string"){x=A.dE(j)
if(x!=null)q.a=A.aM(r,null).a9(x)}o=e.h(0,"userEmail")
if(o==null)o=e.h(0,"userName")
w=J.L(o==null?"Admin":o)
o=e.h(0,"entityType")
v=J.L(o==null?"":o)
o=e.h(0,"entityId")
u=J.L(o==null?"":o)
o=y.y
t=o.b(e.h(0,"details"))?o.a(e.h(0,"details")):null
o=p?D.avj:B.B
A.dP(o,new C.bPn(q,s,l,m,n,k,w,v,u,t,p),d,!0,B.ec,!1,!1,y.b)},
a65(d,e,f){var x=null,w=y.u,v=A.a([],w)
B.h.B(v,A.a([A.Y(f,B.ax,x,x,16),B.E],w))
v.push(A.bo(A.c(d,x,x,x,x,A.z(x,x,B.ax,x,x,x,x,x,x,x,x,12.5,x,x,x,x,x,!0,x,x,x,x,x,x,x,x),x,x,x),x,130))
v.push(A.M(A.c(e,x,x,x,x,B.e2,x,x,x),1,x))
return new A.V(B.Hp,A.u(v,B.k,B.f,B.i,0,x,x),x)},
P(d){var x,w,v,u,t,s,r=this,q=null,p=r.gV().a4($.aH(),y.v)
if(p==null)p=""
x=A.G(d)
if(p.length===0)return A.c9(A.cq(q,q,q,!0,!0,q,q,1,q,q,q,!1,q,!1,q,q,A.aK(q,q,q,B.bC,q,q,new C.bPw(d),q,q,q,"Back",q),q,!0,q,q,q,q,q,D.cwM,q,q,q,1,q,!0),q,E.R6,q,!1,q,q)
w=$.h
v=(w==null?$.h=$.K():w).D("[DEFAULT]")
A.H(v,$.a9(),!0)
u=A.a3(new A.J(v)).m("libraries").u(p).m("audit_log").cN()
w=A.aK(q,q,q,B.bC,q,q,new C.bPx(d),q,q,q,"Back",q)
t=r.x.length!==0?A.aK(q,q,q,B.vN,q,q,new C.bPy(r),q,q,q,q,q):q
s=y.u
return A.c9(A.cq(q,q,q,!0,!0,q,new A.Uw(new A.V(D.aAo,A.bX(q,B.an,!1,q,!0,B.z,q,A.c_(),r.y,q,q,q,q,q,2,A.cc(q,new A.eN(4,A.i(10),B.D),q,B.hl,q,q,q,q,!0,q,q,q,q,q,q,q,!0,q,q,q,q,q,q,q,q,q,q,q,q,q,q,"Search by student, receipt, action, or admin...",q,q,q,q,q,!0,q,q,q,!0,!0,!1,q,D.aJw,q,q,q,q,q,q,t,q,q,q,q,q),B.J,!0,q,!0,q,!1,q,B.aC,q,q,q,q,q,q,q,q,1,q,q,!1,"\u2022",q,new C.bPz(r),q,q,q,!1,q,q,!1,q,!0,q,B.ah,q,q,q,q,q,q,q,q,q,q,q,q,!0,B.Q,q,B.R,q,q,q,q),q),D.ccu,q),1,q,q,q,!1,q,!1,q,q,w,q,!0,q,q,q,q,q,D.cHl,q,q,q,1,q,!0),q,A.A(A.a([A.bZ(A.u(A.a([r.Gr("All Events","all"),B.E,r.Gr("Students","student"),B.E,r.Gr("Receipts & Fees","receipt"),B.E,r.Gr("Seats & Layout","seat"),B.E,r.Gr("Security & Logins","login"),B.E,r.Gr("System & Backup","system")],s),B.k,B.f,B.i,0,q,q),q,B.J,q,B.di,q,q,B.aa),B.bV,A.M(A.hv(new C.bPA(r,x.ax.a===B.aw),q,u,y.t),1,q)],s),B.k,q,B.f,B.i,0,B.o),q,!1,q,q)},
Gr(d,e){var x=null,w=this.w
return A.h4(x,x,A.c(d,x,x,x,x,x,x,x,x),x,x,new C.bPj(this,e),x,w===e,x,x,B.ay)}}
var z=a.updateTypes([])
C.bPn.prototype={
$1(d){var x=this
return A.na(new C.bPm(x.a,x.b,x.c,x.d,x.e,x.f,x.r,x.w,x.x,x.y,x.z,d),!1,0.6,0.9,0.4)},
$S:150}
C.bPm.prototype={
$2(d,e){var x,w=this,v=null,u=A.aG(A.w(v,v,B.n,v,v,new A.x(B.c1,v,v,A.i(2),v,v,B.u),v,4,v,B.dT,v,v,v,40),v,v),t=A.i(6),s=w.d,r=A.a6(s,1.2),q=w.b,p=y.u
t=A.a([u,A.u(A.a([A.w(v,A.c(q.aru(w.e),v,v,v,v,A.z(v,v,s,v,v,v,v,v,v,v,v,11,v,v,B.w,v,v,!0,v,0.8,v,v,v,v,v,v),v,v,v),B.n,v,v,new A.x(w.c,v,r,t,v,v,B.u),v,v,v,v,B.cW,v,v,v),B.ak,A.M(A.c(w.a.a,v,v,v,v,A.z(v,v,B.ax,v,v,v,v,v,v,v,v,12,v,v,v,v,v,!0,v,v,v,v,v,v,v,v),v,v,v),1,v)],p),B.k,B.f,B.i,0,v,v),B.G,A.c(w.f,v,v,v,v,B.cL,v,v,v),B.N,B.eM,B.P,q.a65("Actor / Performed By",w.r,B.IF)],p)
u=w.w
if(u.length!==0)t.push(q.a65("Entity Category",u.toUpperCase(),B.Vd))
u=w.x
if(u.length!==0)t.push(q.a65("Entity Record ID",u,B.pz))
u=w.y
if(u!=null&&u.gcb(u)){s=w.z
r=s?D.avX:B.fH
q=A.i(10)
x=A.a6(s?B.eJ:B.bE,1)
u=u.gdA()
B.h.B(t,A.a([B.G,D.cCU,B.P,A.w(v,A.A(u.dJ(u,new C.bPk(),y.x).cI(0),B.y,v,B.f,B.i,0,B.o),B.n,v,v,new A.x(r,v,x,q,v,v,B.u),v,v,v,v,B.aT,v,v,v)],p))}t.push(B.bj)
t.push(A.jV(D.aKY,B.lY,new C.bPl(w.Q),v))
return A.fi(t,e,D.aB6,v,v,!1)},
$S:1817}
C.bPk.prototype={
$1(d){var x=null
return new A.V(B.Hn,A.u(A.a([A.bo(A.c(d.a,x,x,x,x,A.z(x,x,B.ax,x,x,x,x,x,x,x,x,12,x,x,B.a1,x,x,!0,x,x,x,x,x,x,x,x),x,x,x),x,120),A.M(A.c(A.r(d.b),x,x,x,x,B.ai5,x,x,x),1,x)],y.u),B.y,B.f,B.i,0,x,x),x)},
$S:1818}
C.bPl.prototype={
$0(){A.a8(this.a,!1).T(null)
return null},
$S:0}
C.bPw.prototype={
$0(){var x=this.a,w=A.ad(x).c
w===$&&A.b()
return w.co()?A.ad(x).T(null):A.ad(x).b4("/admin/home",null)},
$S:0}
C.bPx.prototype={
$0(){var x=this.a,w=A.ad(x).c
w===$&&A.b()
return w.co()?A.ad(x).T(null):A.ad(x).b4("/admin/home",null)},
$S:0}
C.bPy.prototype={
$0(){var x=this.a
x.v(new C.bPv(x))},
$S:0}
C.bPv.prototype={
$0(){var x=this.a
x.x=""
x.y.fY(B.fw)},
$S:0}
C.bPz.prototype={
$1(d){var x=this.a
return x.v(new C.bPu(x,d))},
$S:11}
C.bPu.prototype={
$0(){return this.a.x=B.d.q(this.b).toLowerCase()},
$S:0}
C.bPA.prototype={
$2(d,e){var x,w,v,u,t
if(e.a===B.f0)return B.ba
x=e.b
w=x==null?null:x.ga2()
if(w==null)w=A.a([],y.C)
if(w.length===0)return D.aC8
x=A.ab(w).i("X<1,ag<e,@>>")
v=A.Z(new A.X(w,new C.bPp(),x),x.i("aJ.E"))
B.h.cG(v,new C.bPq())
x=this.a
u=A.ab(v).i("au<1>")
t=A.Z(new A.au(v,new C.bPr(x),u),u.i("P.E"))
u=t.length
if(u===0)return D.arv
return A.lI(null,new C.bPs(x,t,this.b),u,B.hM,null,new C.bPt(),!1)},
$S:94}
C.bPp.prototype={
$1(d){return d.I()},
$S:110}
C.bPq.prototype={
$2(d,e){var x,w,v="timestamp",u=d.h(0,v),t=e.h(0,v),s=A.ay(1970,1,1,0,0,0,0),r=A.ay(1970,1,1,0,0,0,0)
if(u instanceof A.dZ)s=A.eC(u.gbd())
if(t instanceof A.dZ)r=A.eC(t.gbd())
if(typeof u=="string"){x=A.dE(u)
s=x==null?s:x}if(typeof t=="string"){w=A.dE(t)
r=w==null?r:w}return r.b6(0,s)},
$S:178}
C.bPr.prototype={
$1(d){var x,w,v,u,t,s=d.h(0,"action"),r=J.L(s==null?"":s).toLowerCase()
s=d.h(0,"entityType")
x=J.L(s==null?"":s).toLowerCase()
s=this.a
w=s.a8m(d)
v=d.h(0,"userEmail")
if(v==null)v=d.h(0,"userName")
v=J.L(v==null?"":v)
u=s.w
if(u==="student"&&x!=="student"&&!B.d.k(r,"student"))return!1
if(u==="receipt"&&x!=="receipt"&&x!=="payment"&&!B.d.k(r,"receipt"))return!1
t=!1
if(u==="seat")if(x!=="seat")if(x!=="section")if(!B.d.k(r,"seat")){u=d.h(0,"details")
if((u==null?null:J.k(u,"seatId"))==null){u=d.h(0,"details")
u=(u==null?null:J.k(u,"sectionId"))==null}else u=t}else u=t
else u=t
else u=t
else u=t
if(u)return!1
u=s.w
if(u==="login"&&r!=="login"&&!B.d.k(r,"auth"))return!1
if(u==="system"&&r!=="exported"&&r!=="imported"&&x!=="settings")return!1
s=s.x
if(s.length!==0)if(!(B.d.k(w.toLowerCase(),s)||B.d.k(v.toLowerCase(),s)||B.d.k(r,s)||B.d.k(x,s)))return!1
return!0},
$S:25}
C.bPt.prototype={
$2(d,e){return B.bV},
$S:78}
C.bPs.prototype={
$2(d,e){var x,w,v,u,t,s,r,q,p,o,n,m=null,l=this.b[e],k=l.h(0,"action"),j=J.L(k==null?"":k)
k=this.a
x=k.a8m(l)
w=l.h(0,"userEmail")
if(w==null)w=l.h(0,"userName")
v=J.L(w==null?"Admin":w)
u=l.h(0,"timestamp")
if(u!=null){t=u instanceof A.dZ?A.eC(u.gbd()):m
if(typeof u=="string")t=A.dE(u)
s=t!=null?A.aM("dd MMM yyyy, hh:mm a",m).a9(t):""}else s=""
w=this.c
r=k.a8p(j,w)
q=k.arv(j,w)
w=A.i(6)
p=A.a6(r,1.2)
w=A.w(m,A.c(k.aru(j),m,m,m,m,A.z(m,m,r,m,m,m,m,m,m,m,m,10,m,m,B.w,m,m,!0,m,0.6,m,m,m,m,m,m),m,m,m),B.n,m,m,new A.x(q,m,p,w,m,m,B.u),m,m,m,m,B.cY,m,m,m)
p=A.c(x,m,m,m,m,B.hy,m,m,m)
o=y.u
n=A.a([A.Y(B.IF,B.ax,m,m,13),B.ao,A.M(A.c(v,1,B.a0,m,m,A.z(m,m,B.ax,m,m,m,m,m,m,m,m,11.5,m,m,m,m,m,!0,m,m,m,m,m,m,m,m),m,m,m),1,m)],o)
if(s.length!==0)B.h.B(n,A.a([B.E,A.c(s,m,m,m,m,A.z(m,m,B.ej,m,m,m,m,m,m,m,m,11,m,m,m,m,m,!0,m,m,m,m,m,m,m,m),m,m,m)],o))
return A.bp(!1,m,!0,new A.V(B.hQ,A.u(A.a([w,B.a3,A.M(A.A(A.a([p,B.aJ,A.u(n,B.k,B.f,B.i,0,m,m)],o),B.y,m,B.f,B.i,0,B.o),1,m),B.ap,B.Jx],o),B.y,B.f,B.i,0,m,m),m),m,!0,m,m,m,m,m,m,m,m,m,m,m,new C.bPo(k,d,l),m,m,m,m,m,m,m)},
$S:119}
C.bPo.prototype={
$0(){return this.a.bsG(this.b,this.c)},
$S:0}
C.bPj.prototype={
$1(d){var x=this.a
return x.v(new C.bPi(x,this.b))},
$S:2}
C.bPi.prototype={
$0(){return this.a.w=this.b},
$S:0};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(C.Du,A.ot)
x(C.aBz,A.nI)
w(A.m4,[C.bPn,C.bPk,C.bPz,C.bPp,C.bPr,C.bPj])
w(A.os,[C.bPm,C.bPA,C.bPq,C.bPt,C.bPs])
w(A.or,[C.bPl,C.bPw,C.bPx,C.bPy,C.bPv,C.bPu,C.bPo,C.bPi])})()
A.vg(b.typeUniverse,JSON.parse('{"Du":{"ak":[],"t":[]},"aBz":{"ap":["Du"]}}'))
var y={C:A.az("a2<fx<ag<e,@>>>"),u:A.az("a2<t>"),y:A.az("ag<e,@>"),x:A.az("V"),t:A.az("dl<ag<e,@>>"),w:A.az("e"),b:A.az("@"),v:A.az("e?")};(function constants(){D.cCJ=new A.f("No matching audit records for this filter.",null,B.i4,null,null,null,null,null,null,null,null)
D.c_R=new A.V(B.eO,D.cCJ,null)
D.arv=new A.d_(B.a6,null,null,D.c_R,null)
D.avj=new A.R(1,0.11764705882352941,0.11764705882352941,0.11764705882352941,B.A)
D.avX=new A.R(1,0.1568627450980392,0.1568627450980392,0.1568627450980392,B.A)
D.aAo=new A.aj(16,0,16,10)
D.aB6=new A.aj(20,16,20,32)
D.aFG=new A.a1(61509,"MaterialIcons",null,!1)
D.aC8=new A.xQ(D.aFG,"No audit records found","All your administrative actions, payments, and seat updates will appear here in real-time.",null,null,null)
D.aJw=new A.y(B.rE,20,null,null,null)
D.aKY=new A.y(B.mx,18,null,null,null)
D.ccu=new A.al(1/0,60)
D.cwM=new A.f("Audit Log",null,null,null,null,null,null,null,null,null,null)
D.cCU=new A.f("Operation Parameters & Details",null,B.bw,null,null,null,null,null,null,null,null)
D.cHl=new A.f("Audit Trail & Activity Log",null,null,null,null,null,null,null,null,null,null)})()};
(a=>{a["iP90gLLQ5J5slo3TfXFv/sWWzWg="]=a.current})($__dart_deferred_initializers__);