((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,B,C={
dB3(){return new C.Dy(null)},
Dy:function Dy(d){this.a=d},
aBD:function aBD(d){var _=this
_.w="all"
_.x=""
_.y=d
_.d=$
_.c=_.a=null},
bPG:function bPG(d,e,f,g,h,i,j,k,l,m,n){var _=this
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
bPF:function bPF(d,e,f,g,h,i,j,k,l,m,n,o){var _=this
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
bPD:function bPD(){},
bPE:function bPE(d){this.a=d},
bPP:function bPP(d){this.a=d},
bPQ:function bPQ(d){this.a=d},
bPR:function bPR(d){this.a=d},
bPO:function bPO(d){this.a=d},
bPS:function bPS(d){this.a=d},
bPN:function bPN(d,e){this.a=d
this.b=e},
bPT:function bPT(d,e){this.a=d
this.b=e},
bPI:function bPI(){},
bPJ:function bPJ(){},
bPK:function bPK(d){this.a=d},
bPM:function bPM(){},
bPL:function bPL(d,e,f){this.a=d
this.b=e
this.c=f},
bPH:function bPH(d,e,f){this.a=d
this.b=e
this.c=f},
bPC:function bPC(d,e){this.a=d
this.b=e},
bPB:function bPB(d,e){this.a=d
this.b=e}},D,E
J=c[1]
A=c[0]
B=c[2]
C=a.updateHolder(c[13],C)
D=c[18]
E=c[19]
C.Dy.prototype={
a7(){return new C.aBD(new A.aA(B.at,$.ax()))}}
C.aBD.prototype={
t(){var x=this.y
x.X$=$.ax()
x.Z$=0
this.aA()},
arC(d){d=d.toLowerCase()
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
a8v(d,e){d=d.toLowerCase()
if(d==="created"||d==="add"||d==="approved")return e?B.fL:B.cl
if(d==="deleted"||d==="remove"||d==="rejected"||d==="voided")return e?B.hM:B.h2
if(d==="updated"||d==="edit")return e?B.nl:B.hj
if(d==="restored")return e?B.Rk:B.Ro
if(d==="login")return e?B.oX:B.iM
if(d==="exported"||d==="imported")return e?B.yG:B.Sk
return e?B.c3:B.lJ},
arD(d,e){var x=this.a8v(d,e)
return x.n(e?0.2:0.12)},
a8s(d){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i="amount",h="studentName",g=d.h(0,"action"),f=J.K(g==null?"":g).toLowerCase()
g=d.h(0,"entityType")
x=J.K(g==null?"":g).toLowerCase()
g=d.h(0,"entityName")
w=g==null?null:J.K(g)
g=y.y
v=g.b(d.h(0,"details"))?g.a(d.h(0,"details")):A.I(y.w,y.b)
if(x==="receipt"){g=v.h(0,"receiptNumber")
u=g==null?w:g
if(u==null)u=""
t=v.h(0,i)!=null?"\u20b9"+A.r(v.h(0,i)):""
if(f==="deleted"){g=A.r(J.eB(u)?u:"")
s=t.length!==0?"("+t+")":""
return B.d.q("Deleted Fee Receipt #"+g+" "+s)}if(f==="created"){g=A.r(J.eB(u)?u:"")
s=t.length!==0?"("+t+")":""
return B.d.q("Generated Fee Receipt #"+g+" "+s)}return B.d.q("Receipt #"+A.r(J.eB(u)?u:"")+" ("+f+")")}if(x==="payment"){g=v.h(0,i)
t=g==null?v.h(0,"deletedAmount"):g
if(t==null)t=""
r=J.K(t).length!==0?"\u20b9"+A.r(t):""
g=v.h(0,"event")
q=g==null?null:J.K(g)
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
if(f==="updated")return"Updated Seat / Layout "+(J.eB(o)?"#"+A.r(o):"")
if(f==="created")return"Created Seat / Section "+A.r(J.eB(o)?o:"")
return B.d.q(f+" Seat "+A.r(o))}if(f==="login"){g=v.h(0,"email")
n=g==null?d.h(0,"userEmail"):g
return"Admin Login: "+A.r(n==null?"Admin":n)}if(x==="request"){m=w==null?v.h(0,h):w
if(m==null)m="Student"
if(f==="approved")return"Approved Admission for "+A.r(m)
if(f==="rejected")return"Rejected Admission for "+A.r(m)
return"Admission Request: "+A.r(m)+" ("+f+")"}if(f==="exported")return"Created Full System Backup"
if(f==="imported")return"Restored Data from Backup File"
g=d.h(0,"message")
l=g==null?null:J.K(g)
if(l!=null&&l.length!==0)return l
k=f.length!==0?f[0].toUpperCase()+B.d.bo(f,1):"Action"
j=x.length!==0?x[0].toUpperCase()+B.d.bo(x,1):""
g=w==null?"":w
return B.d.q(k+" "+j+" "+g)},
bt2(d,e){var x,w,v,u,t,s=this,r="dd MMMM yyyy, hh:mm:ss a",q={},p=A.G(d).ax.a===B.aw,o=e.h(0,"action"),n=J.K(o==null?"":o),m=s.a8v(n,p),l=s.arD(n,p),k=s.a8s(e),j=e.h(0,"timestamp")
q.a="Unknown date"
if(j instanceof A.dX)q.a=A.aM(r,null).a9(A.eD(j.gbe()))
else if(typeof j=="string"){x=A.dD(j)
if(x!=null)q.a=A.aM(r,null).a9(x)}o=e.h(0,"userEmail")
if(o==null)o=e.h(0,"userName")
w=J.K(o==null?"Admin":o)
o=e.h(0,"entityType")
v=J.K(o==null?"":o)
o=e.h(0,"entityId")
u=J.K(o==null?"":o)
o=y.y
t=o.b(e.h(0,"details"))?o.a(e.h(0,"details")):null
o=p?D.avn:B.B
A.dP(o,new C.bPG(q,s,l,m,n,k,w,v,u,t,p),d,!0,B.ed,!1,!1,y.b)},
a6c(d,e,f){var x=null,w=y.u,v=A.a([],w)
B.h.B(v,A.a([A.Z(f,B.ax,x,x,16),B.E],w))
v.push(A.bn(A.c(d,x,x,x,x,A.z(x,x,B.ax,x,x,x,x,x,x,x,x,12.5,x,x,x,x,x,!0,x,x,x,x,x,x,x,x),x,x,x),x,130))
v.push(A.M(A.c(e,x,x,x,x,B.e3,x,x,x),1,x))
return new A.V(B.Hw,A.t(v,B.k,B.f,B.i,0,x,x),x)},
P(d){var x,w,v,u,t,s,r=this,q=null,p=r.gV().a4($.aG(),y.v)
if(p==null)p=""
x=A.G(d)
if(p.length===0)return A.c9(A.cq(q,q,q,!0,!0,q,q,1,q,q,q,!1,q,!1,q,q,A.aK(q,q,q,B.bC,q,q,new C.bPP(d),q,q,q,"Back",q),q,!0,q,q,q,q,q,D.cxd,q,q,q,1,q,!0),q,E.Rc,q,!1,q,q)
w=$.h
v=(w==null?$.h=$.L():w).D("[DEFAULT]")
A.H(v,$.a9(),!0)
u=A.a3(new A.J(v)).m("libraries").u(p).m("audit_log").cO()
w=A.aK(q,q,q,B.bC,q,q,new C.bPQ(d),q,q,q,"Back",q)
t=r.x.length!==0?A.aK(q,q,q,B.vT,q,q,new C.bPR(r),q,q,q,q,q):q
s=y.u
return A.c9(A.cq(q,q,q,!0,!0,q,new A.UC(new A.V(D.aAt,A.bW(q,B.al,!1,q,!0,B.z,q,A.bZ(),r.y,q,q,q,q,q,2,A.cc(q,new A.eO(4,A.i(10),B.D),q,B.ho,q,q,q,q,!0,q,q,q,q,q,q,q,!0,q,q,q,q,q,q,q,q,q,q,q,q,q,q,"Search by student, receipt, action, or admin...",q,q,q,q,q,!0,q,q,q,!0,!0,!1,q,D.aJD,q,q,q,q,q,q,t,q,q,q,q,q),B.J,!0,q,!0,q,!1,q,B.aB,q,q,q,q,q,q,q,q,1,q,q,!1,"\u2022",q,new C.bPS(r),q,q,q,!1,q,q,!1,q,!0,q,B.ai,q,q,q,q,q,q,q,q,q,q,q,q,!0,B.Q,q,B.R,q,q,q,q),q),D.ccS,q),1,q,q,q,!1,q,!1,q,q,w,q,!0,q,q,q,q,q,D.cHQ,q,q,q,1,q,!0),q,A.A(A.a([A.bY(A.t(A.a([r.Gx("All Events","all"),B.E,r.Gx("Students","student"),B.E,r.Gx("Receipts & Fees","receipt"),B.E,r.Gx("Seats & Layout","seat"),B.E,r.Gx("Security & Logins","login"),B.E,r.Gx("System & Backup","system")],s),B.k,B.f,B.i,0,q,q),q,B.J,q,B.dh,q,q,B.aa),B.bX,A.M(A.hw(new C.bPT(r,x.ax.a===B.aw),q,u,y.t),1,q)],s),B.k,q,B.f,B.i,0,B.o),q,!1,q,q)},
Gx(d,e){var x=null,w=this.w
return A.h5(x,x,A.c(d,x,x,x,x,x,x,x,x),x,x,new C.bPC(this,e),x,w===e,x,x,B.ay)}}
var z=a.updateTypes([])
C.bPG.prototype={
$1(d){var x=this
return A.na(new C.bPF(x.a,x.b,x.c,x.d,x.e,x.f,x.r,x.w,x.x,x.y,x.z,d),!1,0.6,0.9,0.4)},
$S:160}
C.bPF.prototype={
$2(d,e){var x,w=this,v=null,u=A.aH(A.w(v,v,B.n,v,v,new A.x(B.c3,v,v,A.i(2),v,v,B.u),v,4,v,B.dZ,v,v,v,40),v,v),t=A.i(6),s=w.d,r=A.a6(s,1.2),q=w.b,p=y.u
t=A.a([u,A.t(A.a([A.w(v,A.c(q.arC(w.e),v,v,v,v,A.z(v,v,s,v,v,v,v,v,v,v,v,11,v,v,B.w,v,v,!0,v,0.8,v,v,v,v,v,v),v,v,v),B.n,v,v,new A.x(w.c,v,r,t,v,v,B.u),v,v,v,v,B.cW,v,v,v),B.ak,A.M(A.c(w.a.a,v,v,v,v,A.z(v,v,B.ax,v,v,v,v,v,v,v,v,12,v,v,v,v,v,!0,v,v,v,v,v,v,v,v),v,v,v),1,v)],p),B.k,B.f,B.i,0,v,v),B.G,A.c(w.f,v,v,v,v,B.cL,v,v,v),B.O,B.eP,B.P,q.a6c("Actor / Performed By",w.r,B.IM)],p)
u=w.w
if(u.length!==0)t.push(q.a6c("Entity Category",u.toUpperCase(),B.Vj))
u=w.x
if(u.length!==0)t.push(q.a6c("Entity Record ID",u,B.pD))
u=w.y
if(u!=null&&u.gcb(u)){s=w.z
r=s?D.aw0:B.fK
q=A.i(10)
x=A.a6(s?B.eM:B.bE,1)
u=u.gdC()
B.h.B(t,A.a([B.G,D.cDn,B.P,A.w(v,A.A(u.dM(u,new C.bPD(),y.x).cK(0),B.y,v,B.f,B.i,0,B.o),B.n,v,v,new A.x(r,v,x,q,v,v,B.u),v,v,v,v,B.aT,v,v,v)],p))}t.push(B.bj)
t.push(A.jV(D.aL5,B.m1,new C.bPE(w.Q),v))
return A.fj(t,e,D.aBc,v,v,!1)},
$S:1824}
C.bPD.prototype={
$1(d){var x=null
return new A.V(B.Hu,A.t(A.a([A.bn(A.c(d.a,x,x,x,x,A.z(x,x,B.ax,x,x,x,x,x,x,x,x,12,x,x,B.a1,x,x,!0,x,x,x,x,x,x,x,x),x,x,x),x,120),A.M(A.c(A.r(d.b),x,x,x,x,B.ai8,x,x,x),1,x)],y.u),B.y,B.f,B.i,0,x,x),x)},
$S:1825}
C.bPE.prototype={
$0(){A.a8(this.a,!1).T(null)
return null},
$S:0}
C.bPP.prototype={
$0(){var x=this.a,w=A.ad(x).c
w===$&&A.b()
return w.cq()?A.ad(x).T(null):A.ad(x).b4("/admin/home",null)},
$S:0}
C.bPQ.prototype={
$0(){var x=this.a,w=A.ad(x).c
w===$&&A.b()
return w.cq()?A.ad(x).T(null):A.ad(x).b4("/admin/home",null)},
$S:0}
C.bPR.prototype={
$0(){var x=this.a
x.v(new C.bPO(x))},
$S:0}
C.bPO.prototype={
$0(){var x=this.a
x.x=""
x.y.h_(B.fz)},
$S:0}
C.bPS.prototype={
$1(d){var x=this.a
return x.v(new C.bPN(x,d))},
$S:11}
C.bPN.prototype={
$0(){return this.a.x=B.d.q(this.b).toLowerCase()},
$S:0}
C.bPT.prototype={
$2(d,e){var x,w,v,u,t
if(e.a===B.f2)return B.ba
x=e.b
w=x==null?null:x.ga2()
if(w==null)w=A.a([],y.C)
if(w.length===0)return D.aCd
x=A.ab(w).i("X<1,ag<e,@>>")
v=A.Y(new A.X(w,new C.bPI(),x),x.i("aJ.E"))
B.h.cI(v,new C.bPJ())
x=this.a
u=A.ab(v).i("au<1>")
t=A.Y(new A.au(v,new C.bPK(x),u),u.i("P.E"))
u=t.length
if(u===0)return D.arz
return A.lI(null,new C.bPL(x,t,this.b),u,B.hP,null,new C.bPM(),!1)},
$S:90}
C.bPI.prototype={
$1(d){return d.I()},
$S:106}
C.bPJ.prototype={
$2(d,e){var x,w,v="timestamp",u=d.h(0,v),t=e.h(0,v),s=A.ay(1970,1,1,0,0,0,0),r=A.ay(1970,1,1,0,0,0,0)
if(u instanceof A.dX)s=A.eD(u.gbe())
if(t instanceof A.dX)r=A.eD(t.gbe())
if(typeof u=="string"){x=A.dD(u)
s=x==null?s:x}if(typeof t=="string"){w=A.dD(t)
r=w==null?r:w}return r.b6(0,s)},
$S:167}
C.bPK.prototype={
$1(d){var x,w,v,u,t,s=d.h(0,"action"),r=J.K(s==null?"":s).toLowerCase()
s=d.h(0,"entityType")
x=J.K(s==null?"":s).toLowerCase()
s=this.a
w=s.a8s(d)
v=d.h(0,"userEmail")
if(v==null)v=d.h(0,"userName")
v=J.K(v==null?"":v)
u=s.w
if(u==="student"&&x!=="student"&&!B.d.k(r,"student"))return!1
if(u==="receipt"&&x!=="receipt"&&x!=="payment"&&!B.d.k(r,"receipt"))return!1
t=!1
if(u==="seat")if(x!=="seat")if(x!=="section")if(!B.d.k(r,"seat")){u=d.h(0,"details")
if((u==null?null:J.j(u,"seatId"))==null){u=d.h(0,"details")
u=(u==null?null:J.j(u,"sectionId"))==null}else u=t}else u=t
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
$S:23}
C.bPM.prototype={
$2(d,e){return B.bX},
$S:84}
C.bPL.prototype={
$2(d,e){var x,w,v,u,t,s,r,q,p,o,n,m=null,l=this.b[e],k=l.h(0,"action"),j=J.K(k==null?"":k)
k=this.a
x=k.a8s(l)
w=l.h(0,"userEmail")
if(w==null)w=l.h(0,"userName")
v=J.K(w==null?"Admin":w)
u=l.h(0,"timestamp")
if(u!=null){t=u instanceof A.dX?A.eD(u.gbe()):m
if(typeof u=="string")t=A.dD(u)
s=t!=null?A.aM("dd MMM yyyy, hh:mm a",m).a9(t):""}else s=""
w=this.c
r=k.a8v(j,w)
q=k.arD(j,w)
w=A.i(6)
p=A.a6(r,1.2)
w=A.w(m,A.c(k.arC(j),m,m,m,m,A.z(m,m,r,m,m,m,m,m,m,m,m,10,m,m,B.w,m,m,!0,m,0.6,m,m,m,m,m,m),m,m,m),B.n,m,m,new A.x(q,m,p,w,m,m,B.u),m,m,m,m,B.cY,m,m,m)
p=A.c(x,m,m,m,m,B.hA,m,m,m)
o=y.u
n=A.a([A.Z(B.IM,B.ax,m,m,13),B.am,A.M(A.c(v,1,B.a0,m,m,A.z(m,m,B.ax,m,m,m,m,m,m,m,m,11.5,m,m,m,m,m,!0,m,m,m,m,m,m,m,m),m,m,m),1,m)],o)
if(s.length!==0)B.h.B(n,A.a([B.E,A.c(s,m,m,m,m,A.z(m,m,B.ek,m,m,m,m,m,m,m,m,11,m,m,m,m,m,!0,m,m,m,m,m,m,m,m),m,m,m)],o))
return A.bp(!1,m,!0,new A.V(B.hT,A.t(A.a([w,B.a2,A.M(A.A(A.a([p,B.aJ,A.t(n,B.k,B.f,B.i,0,m,m)],o),B.y,m,B.f,B.i,0,B.o),1,m),B.ap,B.JE],o),B.y,B.f,B.i,0,m,m),m),m,!0,m,m,m,m,m,m,m,m,m,m,m,new C.bPH(k,d,l),m,m,m,m,m,m,m)},
$S:105}
C.bPH.prototype={
$0(){return this.a.bt2(this.b,this.c)},
$S:0}
C.bPC.prototype={
$1(d){var x=this.a
return x.v(new C.bPB(x,this.b))},
$S:2}
C.bPB.prototype={
$0(){return this.a.w=this.b},
$S:0};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(C.Dy,A.ou)
x(C.aBD,A.nI)
w(A.m4,[C.bPG,C.bPD,C.bPS,C.bPI,C.bPK,C.bPC])
w(A.ot,[C.bPF,C.bPT,C.bPJ,C.bPM,C.bPL])
w(A.os,[C.bPE,C.bPP,C.bPQ,C.bPR,C.bPO,C.bPN,C.bPH,C.bPB])})()
A.vk(b.typeUniverse,JSON.parse('{"Dy":{"ak":[],"u":[]},"aBD":{"ap":["Dy"]}}'))
var y={C:A.az("a2<fz<ag<e,@>>>"),u:A.az("a2<u>"),y:A.az("ag<e,@>"),x:A.az("V"),t:A.az("dj<ag<e,@>>"),w:A.az("e"),b:A.az("@"),v:A.az("e?")};(function constants(){D.cDc=new A.f("No matching audit records for this filter.",null,B.i8,null,null,null,null,null,null,null,null)
D.c0e=new A.V(B.eR,D.cDc,null)
D.arz=new A.d_(B.a6,null,null,D.c0e,null)
D.avn=new A.R(1,0.11764705882352941,0.11764705882352941,0.11764705882352941,B.A)
D.aw0=new A.R(1,0.1568627450980392,0.1568627450980392,0.1568627450980392,B.A)
D.aAt=new A.aj(16,0,16,10)
D.aBc=new A.aj(20,16,20,32)
D.aFL=new A.a1(61509,"MaterialIcons",null,!1)
D.aCd=new A.xT(D.aFL,"No audit records found","All your administrative actions, payments, and seat updates will appear here in real-time.",null,null,null)
D.aJD=new A.y(B.rM,20,null,null,null)
D.aL5=new A.y(B.mB,18,null,null,null)
D.ccS=new A.al(1/0,60)
D.cxd=new A.f("Audit Log",null,null,null,null,null,null,null,null,null,null)
D.cDn=new A.f("Operation Parameters & Details",null,B.bw,null,null,null,null,null,null,null,null)
D.cHQ=new A.f("Audit Trail & Activity Log",null,null,null,null,null,null,null,null,null,null)})()};
(a=>{a["2zCcGE/7mDqcEuc+s0mmE8Urm7A="]=a.current})($__dart_deferred_initializers__);