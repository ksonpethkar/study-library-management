((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,B,C={
dE5(){return new C.DW(null)},
DW:function DW(d){this.a=d},
aCE:function aCE(d){var _=this
_.w="all"
_.x=""
_.y=d
_.d=$
_.c=_.a=null},
bRo:function bRo(d,e,f,g,h,i,j,k,l,m,n){var _=this
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
bRn:function bRn(d,e,f,g,h,i,j,k,l,m,n,o){var _=this
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
bRl:function bRl(){},
bRm:function bRm(d){this.a=d},
bRx:function bRx(d){this.a=d},
bRy:function bRy(d){this.a=d},
bRz:function bRz(d){this.a=d},
bRw:function bRw(d){this.a=d},
bRA:function bRA(d){this.a=d},
bRv:function bRv(d,e){this.a=d
this.b=e},
bRB:function bRB(d,e){this.a=d
this.b=e},
bRq:function bRq(){},
bRr:function bRr(){},
bRs:function bRs(d){this.a=d},
bRu:function bRu(){},
bRt:function bRt(d,e,f){this.a=d
this.b=e
this.c=f},
bRp:function bRp(d,e,f){this.a=d
this.b=e
this.c=f},
bRk:function bRk(d,e){this.a=d
this.b=e},
bRj:function bRj(d,e){this.a=d
this.b=e}},D,E
J=c[1]
A=c[0]
B=c[2]
C=a.updateHolder(c[13],C)
D=c[18]
E=c[19]
C.DW.prototype={
a6(){return new C.aCE(new A.aA(B.as,$.ax()))}}
C.aCE.prototype={
t(){var x=this.y
x.X$=$.ax()
x.Z$=0
this.aA()},
asi(d){d=d.toLowerCase()
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
a95(d,e){d=d.toLowerCase()
if(d==="created"||d==="add"||d==="approved")return e?B.fR:B.cg
if(d==="deleted"||d==="remove"||d==="rejected"||d==="voided")return e?B.hS:B.h8
if(d==="updated"||d==="edit")return e?B.ns:B.hq
if(d==="restored")return e?B.RK:B.RO
if(d==="login")return e?B.p5:B.iP
if(d==="exported"||d==="imported")return e?B.zb:B.SK
return e?B.c1:B.lR},
asj(d,e){var x=this.a95(d,e)
return x.m(e?0.2:0.12)},
a92(d){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i="amount",h="studentName",g=d.h(0,"action"),f=J.K(g==null?"":g).toLowerCase()
g=d.h(0,"entityType")
x=J.K(g==null?"":g).toLowerCase()
g=d.h(0,"entityName")
w=g==null?null:J.K(g)
g=y.y
v=g.b(d.h(0,"details"))?g.a(d.h(0,"details")):A.I(y.w,y.b)
if(x==="receipt"){g=v.h(0,"receiptNumber")
u=g==null?w:g
if(u==null)u=""
t=v.h(0,i)!=null?"\u20b9"+A.q(v.h(0,i)):""
if(f==="deleted"){g=A.q(J.eE(u)?u:"")
s=t.length!==0?"("+t+")":""
return B.d.q("Deleted Fee Receipt #"+g+" "+s)}if(f==="created"){g=A.q(J.eE(u)?u:"")
s=t.length!==0?"("+t+")":""
return B.d.q("Generated Fee Receipt #"+g+" "+s)}return B.d.q("Receipt #"+A.q(J.eE(u)?u:"")+" ("+f+")")}if(x==="payment"){g=v.h(0,i)
t=g==null?v.h(0,"deletedAmount"):g
if(t==null)t=""
r=J.K(t).length!==0?"\u20b9"+A.q(t):""
g=v.h(0,"event")
q=g==null?null:J.K(g)
if((q==null?f:q)==="payment_voided")return B.d.q("Voided Payment "+r)
if(f==="deleted")return B.d.q("Deleted Payment Record "+r)
if(f==="created")return B.d.q("Recorded Payment "+r)
return B.d.q("Payment Updated "+r)}if(x==="student"){g=w==null?v.h(0,"name"):w
p=g==null?v.h(0,h):g
if(p==null)p="Student"
if(f==="created")return"Enrolled Student: "+A.q(p)
if(f==="deleted")return"Moved Student to Recycle Bin: "+A.q(p)
if(f==="restored")return"Restored Student from Bin: "+A.q(p)
if(J.p(v.h(0,"seatAssigned"),!0))return"Assigned Seat to "+A.q(p)
return"Updated Student: "+A.q(p)}if(x==="seat"||x==="section"){g=w==null?v.h(0,"seatId"):w
o=g==null?v.h(0,"sectionName"):g
if(o==null)o=""
if(f==="updated")return"Updated Seat / Layout "+(J.eE(o)?"#"+A.q(o):"")
if(f==="created")return"Created Seat / Section "+A.q(J.eE(o)?o:"")
return B.d.q(f+" Seat "+A.q(o))}if(f==="login"){g=v.h(0,"email")
n=g==null?d.h(0,"userEmail"):g
return"Admin Login: "+A.q(n==null?"Admin":n)}if(x==="request"){m=w==null?v.h(0,h):w
if(m==null)m="Student"
if(f==="approved")return"Approved Admission for "+A.q(m)
if(f==="rejected")return"Rejected Admission for "+A.q(m)
return"Admission Request: "+A.q(m)+" ("+f+")"}if(f==="exported")return"Created Full System Backup"
if(f==="imported")return"Restored Data from Backup File"
g=d.h(0,"message")
l=g==null?null:J.K(g)
if(l!=null&&l.length!==0)return l
k=f.length!==0?f[0].toUpperCase()+B.d.bj(f,1):"Action"
j=x.length!==0?x[0].toUpperCase()+B.d.bj(x,1):""
g=w==null?"":w
return B.d.q(k+" "+j+" "+g)},
buu(d,e){var x,w,v,u,t,s=this,r="dd MMMM yyyy, hh:mm:ss a",q={},p=A.G(d).ax.a===B.ax,o=e.h(0,"action"),n=J.K(o==null?"":o),m=s.a95(n,p),l=s.asj(n,p),k=s.a92(e),j=e.h(0,"timestamp")
q.a="Unknown date"
if(j instanceof A.dY)q.a=A.aL(r,null).a9(A.eG(j.gbe()))
else if(typeof j=="string"){x=A.dB(j)
if(x!=null)q.a=A.aL(r,null).a9(x)}o=e.h(0,"userEmail")
if(o==null)o=e.h(0,"userName")
w=J.K(o==null?"Admin":o)
o=e.h(0,"entityType")
v=J.K(o==null?"":o)
o=e.h(0,"entityId")
u=J.K(o==null?"":o)
o=y.y
t=o.b(e.h(0,"details"))?o.a(e.h(0,"details")):null
o=p?D.aw7:B.B
A.dP(o,new C.bRo(q,s,l,m,n,k,w,v,u,t,p),d,!0,B.ej,!1,!1,y.b)},
a6M(d,e,f){var x=null,w=y.u,v=A.a([],w)
B.h.B(v,A.a([A.Y(f,B.av,x,x,16),B.D],w))
v.push(A.bk(A.c(d,x,x,x,x,A.A(x,x,B.av,x,x,x,x,x,x,x,x,12.5,x,x,x,x,x,!0,x,x,x,x,x,x,x,x),x,x,x),x,130))
v.push(A.J(A.c(e,x,x,x,x,B.dQ,x,x,x),1,x))
return new A.T(B.HP,A.u(v,B.k,B.f,B.i,0,x,x),x)},
P(d){var x,w,v,u,t,s,r=this,q=null,p=r.gV().a4($.aF(),y.v)
if(p==null)p=""
x=A.G(d)
if(p.length===0)return A.cf(A.cu(q,q,q,!0,!0,q,q,1,q,q,q,!1,q,!1,q,q,A.aK(q,q,q,B.bI,q,q,new C.bRx(d),q,q,q,"Back",q),q,!0,q,q,q,q,q,D.czo,q,q,q,1,q,!0),q,E.RD,q,!1,q,q)
w=$.h
v=(w==null?$.h=$.M():w).D("[DEFAULT]")
A.H(v,$.a9(),!0)
u=A.a4(new A.L(v)).n("libraries").v(p).n("audit_log").cQ()
w=A.aK(q,q,q,B.bI,q,q,new C.bRy(d),q,q,q,"Back",q)
t=r.x.length!==0?A.aK(q,q,q,B.wl,q,q,new C.bRz(r),q,q,q,q,q):q
s=y.u
return A.cf(A.cu(q,q,q,!0,!0,q,new A.Vj(new A.T(D.aBq,A.bU(q,B.ak,!1,q,!0,B.z,q,A.bW(),r.y,q,q,q,q,q,2,A.ce(q,new A.eN(4,A.i(10),B.E),q,B.hu,q,q,q,q,!0,q,q,q,q,q,q,q,!0,q,q,q,q,q,q,q,q,q,q,q,q,q,q,"Search by student, receipt, action, or admin...",q,q,q,q,q,!0,q,q,q,!0,!0,!1,q,D.aKL,q,q,q,q,q,q,t,q,q,q,q,q),B.J,!0,q,!0,q,!1,q,B.aB,q,q,q,q,q,q,q,q,1,q,q,!1,"\u2022",q,new C.bRA(r),q,q,q,!1,q,q,!1,q,!0,q,B.ag,q,q,q,q,q,q,q,q,q,q,q,q,!0,B.Q,q,B.R,q,q,q,q),q),D.ceR,q),1,q,q,q,!1,q,!1,q,q,w,q,!0,q,q,q,q,q,D.cKd,q,q,q,1,q,!0),q,A.z(A.a([A.c0(A.u(A.a([r.GR("All Events","all"),B.D,r.GR("Students","student"),B.D,r.GR("Receipts & Fees","receipt"),B.D,r.GR("Seats & Layout","seat"),B.D,r.GR("Security & Logins","login"),B.D,r.GR("System & Backup","system")],s),B.k,B.f,B.i,0,q,q),q,B.J,q,B.dn,q,q,B.ac),B.bY,A.J(A.hy(new C.bRB(r,x.ax.a===B.ax),q,u,y.t),1,q)],s),B.k,q,B.f,B.i,0,B.o),q,!1,q,q)},
GR(d,e){var x=null,w=this.w
return A.h1(x,x,A.c(d,x,x,x,x,x,x,x,x),x,x,new C.bRk(this,e),x,w===e,x,x,B.ay)}}
var z=a.updateTypes([])
C.bRo.prototype={
$1(d){var x=this
return A.nj(new C.bRn(x.a,x.b,x.c,x.d,x.e,x.f,x.r,x.w,x.x,x.y,x.z,d),!1,0.6,0.9,0.4)},
$S:152}
C.bRn.prototype={
$2(d,e){var x,w=this,v=null,u=A.aE(A.w(v,v,B.n,v,v,new A.x(B.c1,v,v,A.i(2),v,v,B.u),v,4,v,B.e3,v,v,v,40),v,v),t=A.i(6),s=w.d,r=A.a5(s,1.2),q=w.b,p=y.u
t=A.a([u,A.u(A.a([A.w(v,A.c(q.asi(w.e),v,v,v,v,A.A(v,v,s,v,v,v,v,v,v,v,v,11,v,v,B.w,v,v,!0,v,0.8,v,v,v,v,v,v),v,v,v),B.n,v,v,new A.x(w.c,v,r,t,v,v,B.u),v,v,v,v,B.d4,v,v,v),B.al,A.J(A.c(w.a.a,v,v,v,v,A.A(v,v,B.av,v,v,v,v,v,v,v,v,12,v,v,v,v,v,!0,v,v,v,v,v,v,v,v),v,v,v),1,v)],p),B.k,B.f,B.i,0,v,v),B.F,A.c(w.f,v,v,v,v,B.cO,v,v,v),B.P,B.eW,B.N,q.a6M("Actor / Performed By",w.r,B.J3)],p)
u=w.w
if(u.length!==0)t.push(q.a6M("Entity Category",u.toUpperCase(),B.VJ))
u=w.x
if(u.length!==0)t.push(q.a6M("Entity Record ID",u,B.pU))
u=w.y
if(u!=null&&u.gc7(u)){s=w.z
r=s?D.awL:B.fQ
q=A.i(10)
x=A.a5(s?B.eq:B.bD,1)
u=u.gdA()
B.h.B(t,A.a([B.F,D.cFF,B.N,A.w(v,A.z(u.dK(u,new C.bRl(),y.x).cF(0),B.x,v,B.f,B.i,0,B.o),B.n,v,v,new A.x(r,v,x,q,v,v,B.u),v,v,v,v,B.aS,v,v,v)],p))}t.push(B.bl)
t.push(A.k0(D.aMe,B.m7,new C.bRm(w.Q),v))
return A.fo(t,e,D.aCc,v,v,!1)},
$S:1850}
C.bRl.prototype={
$1(d){var x=null
return new A.T(B.HN,A.u(A.a([A.bk(A.c(d.a,x,x,x,x,A.A(x,x,B.av,x,x,x,x,x,x,x,x,12,x,x,B.a1,x,x,!0,x,x,x,x,x,x,x,x),x,x,x),x,120),A.J(A.c(A.q(d.b),x,x,x,x,B.aiM,x,x,x),1,x)],y.u),B.x,B.f,B.i,0,x,x),x)},
$S:1851}
C.bRm.prototype={
$0(){A.a8(this.a,!1).R(null)
return null},
$S:0}
C.bRx.prototype={
$0(){var x=this.a,w=A.ae(x).c
w===$&&A.b()
return w.cs()?A.ae(x).R(null):A.ae(x).b5("/admin/home",null)},
$S:0}
C.bRy.prototype={
$0(){var x=this.a,w=A.ae(x).c
w===$&&A.b()
return w.cs()?A.ae(x).R(null):A.ae(x).b5("/admin/home",null)},
$S:0}
C.bRz.prototype={
$0(){var x=this.a
x.u(new C.bRw(x))},
$S:0}
C.bRw.prototype={
$0(){var x=this.a
x.x=""
x.y.fV(B.fr)},
$S:0}
C.bRA.prototype={
$1(d){var x=this.a
return x.u(new C.bRv(x,d))},
$S:8}
C.bRv.prototype={
$0(){return this.a.x=B.d.q(this.b).toLowerCase()},
$S:0}
C.bRB.prototype={
$2(d,e){var x,w,v,u,t
if(e.a===B.fb)return B.ba
x=e.b
w=x==null?null:x.ga3()
if(w==null)w=A.a([],y.C)
if(w.length===0)return D.aDl
x=A.ab(w).i("X<1,af<e,@>>")
v=A.Z(new A.X(w,new C.bRq(),x),x.i("aJ.E"))
B.h.cK(v,new C.bRr())
x=this.a
u=A.ab(v).i("av<1>")
t=A.Z(new A.av(v,new C.bRs(x),u),u.i("P.E"))
u=t.length
if(u===0)return D.asi
return A.lo(null,new C.bRt(x,t,this.b),u,B.hV,null,new C.bRu(),!1)},
$S:90}
C.bRq.prototype={
$1(d){return d.I()},
$S:115}
C.bRr.prototype={
$2(d,e){var x,w,v="timestamp",u=d.h(0,v),t=e.h(0,v),s=A.az(1970,1,1,0,0,0,0),r=A.az(1970,1,1,0,0,0,0)
if(u instanceof A.dY)s=A.eG(u.gbe())
if(t instanceof A.dY)r=A.eG(t.gbe())
if(typeof u=="string"){x=A.dB(u)
s=x==null?s:x}if(typeof t=="string"){w=A.dB(t)
r=w==null?r:w}return r.b8(0,s)},
$S:174}
C.bRs.prototype={
$1(d){var x,w,v,u,t,s=d.h(0,"action"),r=J.K(s==null?"":s).toLowerCase()
s=d.h(0,"entityType")
x=J.K(s==null?"":s).toLowerCase()
s=this.a
w=s.a92(d)
v=d.h(0,"userEmail")
if(v==null)v=d.h(0,"userName")
v=J.K(v==null?"":v)
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
$S:23}
C.bRu.prototype={
$2(d,e){return B.bY},
$S:84}
C.bRt.prototype={
$2(d,e){var x,w,v,u,t,s,r,q,p,o,n,m=null,l=this.b[e],k=l.h(0,"action"),j=J.K(k==null?"":k)
k=this.a
x=k.a92(l)
w=l.h(0,"userEmail")
if(w==null)w=l.h(0,"userName")
v=J.K(w==null?"Admin":w)
u=l.h(0,"timestamp")
if(u!=null){t=u instanceof A.dY?A.eG(u.gbe()):m
if(typeof u=="string")t=A.dB(u)
s=t!=null?A.aL("dd MMM yyyy, hh:mm a",m).a9(t):""}else s=""
w=this.c
r=k.a95(j,w)
q=k.asj(j,w)
w=A.i(6)
p=A.a5(r,1.2)
w=A.w(m,A.c(k.asi(j),m,m,m,m,A.A(m,m,r,m,m,m,m,m,m,m,m,10,m,m,B.w,m,m,!0,m,0.6,m,m,m,m,m,m),m,m,m),B.n,m,m,new A.x(q,m,p,w,m,m,B.u),m,m,m,m,B.cW,m,m,m)
p=A.c(x,m,m,m,m,B.hG,m,m,m)
o=y.u
n=A.a([A.Y(B.J3,B.av,m,m,13),B.an,A.J(A.c(v,1,B.Z,m,m,A.A(m,m,B.av,m,m,m,m,m,m,m,m,11.5,m,m,m,m,m,!0,m,m,m,m,m,m,m,m),m,m,m),1,m)],o)
if(s.length!==0)B.h.B(n,A.a([B.D,A.c(s,m,m,m,m,A.A(m,m,B.dX,m,m,m,m,m,m,m,m,11,m,m,m,m,m,!0,m,m,m,m,m,m,m,m),m,m,m)],o))
return A.bm(!1,m,!0,new A.T(B.hX,A.u(A.a([w,B.a3,A.J(A.z(A.a([p,B.aJ,A.u(n,B.k,B.f,B.i,0,m,m)],o),B.x,m,B.f,B.i,0,B.o),1,m),B.am,B.JW],o),B.x,B.f,B.i,0,m,m),m),m,!0,m,m,m,m,m,m,m,m,m,m,m,new C.bRp(k,d,l),m,m,m,m,m,m,m)},
$S:103}
C.bRp.prototype={
$0(){return this.a.buu(this.b,this.c)},
$S:0}
C.bRk.prototype={
$1(d){var x=this.a
return x.u(new C.bRj(x,this.b))},
$S:2}
C.bRj.prototype={
$0(){return this.a.w=this.b},
$S:0};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(C.DW,A.oB)
x(C.aCE,A.nP)
w(A.ma,[C.bRo,C.bRl,C.bRA,C.bRq,C.bRs,C.bRk])
w(A.oA,[C.bRn,C.bRB,C.bRr,C.bRu,C.bRt])
w(A.oz,[C.bRm,C.bRx,C.bRy,C.bRz,C.bRw,C.bRv,C.bRp,C.bRj])})()
A.vD(b.typeUniverse,JSON.parse('{"DW":{"ak":[],"v":[]},"aCE":{"ap":["DW"]}}'))
var y={C:A.ay("a2<fD<af<e,@>>>"),u:A.ay("a2<v>"),y:A.ay("af<e,@>"),x:A.ay("T"),t:A.ay("dl<af<e,@>>"),w:A.ay("e"),b:A.ay("@"),v:A.ay("e?")};(function constants(){D.cFv=new A.f("No matching audit records for this filter.",null,B.ic,null,null,null,null,null,null,null,null)
D.c1U=new A.T(B.eZ,D.cFv,null)
D.asi=new A.d4(B.a4,null,null,D.c1U,null)
D.aw7=new A.S(1,0.11764705882352941,0.11764705882352941,0.11764705882352941,B.A)
D.awL=new A.S(1,0.1568627450980392,0.1568627450980392,0.1568627450980392,B.A)
D.aBq=new A.ai(16,0,16,10)
D.aCc=new A.ai(20,16,20,32)
D.aGW=new A.a1(61509,"MaterialIcons",null,!1)
D.aDl=new A.yi(D.aGW,"No audit records found","All your administrative actions, payments, and seat updates will appear here in real-time.",null,null,null)
D.aKL=new A.y(B.t2,20,null,null,null)
D.aMe=new A.y(B.mK,18,null,null,null)
D.ceR=new A.am(1/0,60)
D.czo=new A.f("Audit Log",null,null,null,null,null,null,null,null,null,null)
D.cFF=new A.f("Operation Parameters & Details",null,B.bz,null,null,null,null,null,null,null,null)
D.cKd=new A.f("Audit Trail & Activity Log",null,null,null,null,null,null,null,null,null,null)})()};
(a=>{a["bO4MlnzQh91he+NqjJBZqh+SVM0="]=a.current})($__dart_deferred_initializers__);