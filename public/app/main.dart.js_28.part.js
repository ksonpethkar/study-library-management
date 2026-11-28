((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,B,C={
dDM(){return new C.DX(null)},
DX:function DX(d){this.a=d},
aCB:function aCB(d){var _=this
_.w="all"
_.x=""
_.y=d
_.d=$
_.c=_.a=null},
bRl:function bRl(d,e,f,g,h,i,j,k,l,m,n){var _=this
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
bRk:function bRk(d,e,f,g,h,i,j,k,l,m,n,o){var _=this
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
bRi:function bRi(){},
bRj:function bRj(d){this.a=d},
bRu:function bRu(d){this.a=d},
bRv:function bRv(d){this.a=d},
bRw:function bRw(d){this.a=d},
bRt:function bRt(d){this.a=d},
bRx:function bRx(d){this.a=d},
bRs:function bRs(d,e){this.a=d
this.b=e},
bRy:function bRy(d,e){this.a=d
this.b=e},
bRn:function bRn(){},
bRo:function bRo(){},
bRp:function bRp(d){this.a=d},
bRr:function bRr(){},
bRq:function bRq(d,e,f){this.a=d
this.b=e
this.c=f},
bRm:function bRm(d,e,f){this.a=d
this.b=e
this.c=f},
bRh:function bRh(d,e){this.a=d
this.b=e},
bRg:function bRg(d,e){this.a=d
this.b=e}},D,E
J=c[1]
A=c[0]
B=c[2]
C=a.updateHolder(c[13],C)
D=c[18]
E=c[19]
C.DX.prototype={
a6(){return new C.aCB(new A.aA(B.as,$.ax()))}}
C.aCB.prototype={
t(){var x=this.y
x.X$=$.ax()
x.Z$=0
this.aA()},
asg(d){d=d.toLowerCase()
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
a93(d,e){d=d.toLowerCase()
if(d==="created"||d==="add"||d==="approved")return e?B.fP:B.cg
if(d==="deleted"||d==="remove"||d==="rejected"||d==="voided")return e?B.hQ:B.h7
if(d==="updated"||d==="edit")return e?B.ns:B.hp
if(d==="restored")return e?B.RI:B.RM
if(d==="login")return e?B.p5:B.iO
if(d==="exported"||d==="imported")return e?B.z9:B.SI
return e?B.c1:B.lR},
ash(d,e){var x=this.a93(d,e)
return x.m(e?0.2:0.12)},
a90(d){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i="amount",h="studentName",g=d.h(0,"action"),f=J.L(g==null?"":g).toLowerCase()
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
if(f==="deleted"){g=A.r(J.eE(u)?u:"")
s=t.length!==0?"("+t+")":""
return B.d.q("Deleted Fee Receipt #"+g+" "+s)}if(f==="created"){g=A.r(J.eE(u)?u:"")
s=t.length!==0?"("+t+")":""
return B.d.q("Generated Fee Receipt #"+g+" "+s)}return B.d.q("Receipt #"+A.r(J.eE(u)?u:"")+" ("+f+")")}if(x==="payment"){g=v.h(0,i)
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
if(f==="updated")return"Updated Seat / Layout "+(J.eE(o)?"#"+A.r(o):"")
if(f==="created")return"Created Seat / Section "+A.r(J.eE(o)?o:"")
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
k=f.length!==0?f[0].toUpperCase()+B.d.bi(f,1):"Action"
j=x.length!==0?x[0].toUpperCase()+B.d.bi(x,1):""
g=w==null?"":w
return B.d.q(k+" "+j+" "+g)},
buo(d,e){var x,w,v,u,t,s=this,r="dd MMMM yyyy, hh:mm:ss a",q={},p=A.H(d).ax.a===B.ax,o=e.h(0,"action"),n=J.L(o==null?"":o),m=s.a93(n,p),l=s.ash(n,p),k=s.a90(e),j=e.h(0,"timestamp")
q.a="Unknown date"
if(j instanceof A.dX)q.a=A.aL(r,null).a9(A.eG(j.gbd()))
else if(typeof j=="string"){x=A.dB(j)
if(x!=null)q.a=A.aL(r,null).a9(x)}o=e.h(0,"userEmail")
if(o==null)o=e.h(0,"userName")
w=J.L(o==null?"Admin":o)
o=e.h(0,"entityType")
v=J.L(o==null?"":o)
o=e.h(0,"entityId")
u=J.L(o==null?"":o)
o=y.y
t=o.b(e.h(0,"details"))?o.a(e.h(0,"details")):null
o=p?D.aw4:B.B
A.dP(o,new C.bRl(q,s,l,m,n,k,w,v,u,t,p),d,!0,B.ej,!1,!1,y.b)},
a6K(d,e,f){var x=null,w=y.u,v=A.a([],w)
B.h.B(v,A.a([A.Y(f,B.av,x,x,16),B.D],w))
v.push(A.bk(A.c(d,x,x,x,x,A.A(x,x,B.av,x,x,x,x,x,x,x,x,12.5,x,x,x,x,x,!0,x,x,x,x,x,x,x,x),x,x,x),x,130))
v.push(A.J(A.c(e,x,x,x,x,B.dQ,x,x,x),1,x))
return new A.U(B.HN,A.u(v,B.k,B.f,B.i,0,x,x),x)},
P(d){var x,w,v,u,t,s,r=this,q=null,p=r.gV().a4($.aH(),y.v)
if(p==null)p=""
x=A.H(d)
if(p.length===0)return A.ce(A.ct(q,q,q,!0,!0,q,q,1,q,q,q,!1,q,!1,q,q,A.aK(q,q,q,B.bI,q,q,new C.bRu(d),q,q,q,"Back",q),q,!0,q,q,q,q,q,D.cze,q,q,q,1,q,!0),q,E.RB,q,!1,q,q)
w=$.h
v=(w==null?$.h=$.M():w).D("[DEFAULT]")
A.G(v,$.a9(),!0)
u=A.a3(new A.K(v)).n("libraries").u(p).n("audit_log").cQ()
w=A.aK(q,q,q,B.bI,q,q,new C.bRv(d),q,q,q,"Back",q)
t=r.x.length!==0?A.aK(q,q,q,B.wl,q,q,new C.bRw(r),q,q,q,q,q):q
s=y.u
return A.ce(A.ct(q,q,q,!0,!0,q,new A.Vh(new A.U(D.aBn,A.bU(q,B.ak,!1,q,!0,B.z,q,A.bW(),r.y,q,q,q,q,q,2,A.cd(q,new A.eN(4,A.i(10),B.E),q,B.ht,q,q,q,q,!0,q,q,q,q,q,q,q,!0,q,q,q,q,q,q,q,q,q,q,q,q,q,q,"Search by student, receipt, action, or admin...",q,q,q,q,q,!0,q,q,q,!0,!0,!1,q,D.aKJ,q,q,q,q,q,q,t,q,q,q,q,q),B.J,!0,q,!0,q,!1,q,B.aB,q,q,q,q,q,q,q,q,1,q,q,!1,"\u2022",q,new C.bRx(r),q,q,q,!1,q,q,!1,q,!0,q,B.ag,q,q,q,q,q,q,q,q,q,q,q,q,!0,B.Q,q,B.R,q,q,q,q),q),D.ceM,q),1,q,q,q,!1,q,!1,q,q,w,q,!0,q,q,q,q,q,D.cK0,q,q,q,1,q,!0),q,A.z(A.a([A.c0(A.u(A.a([r.GO("All Events","all"),B.D,r.GO("Students","student"),B.D,r.GO("Receipts & Fees","receipt"),B.D,r.GO("Seats & Layout","seat"),B.D,r.GO("Security & Logins","login"),B.D,r.GO("System & Backup","system")],s),B.k,B.f,B.i,0,q,q),q,B.J,q,B.dn,q,q,B.ab),B.bY,A.J(A.hx(new C.bRy(r,x.ax.a===B.ax),q,u,y.t),1,q)],s),B.k,q,B.f,B.i,0,B.o),q,!1,q,q)},
GO(d,e){var x=null,w=this.w
return A.h0(x,x,A.c(d,x,x,x,x,x,x,x,x),x,x,new C.bRh(this,e),x,w===e,x,x,B.ay)}}
var z=a.updateTypes([])
C.bRl.prototype={
$1(d){var x=this
return A.nj(new C.bRk(x.a,x.b,x.c,x.d,x.e,x.f,x.r,x.w,x.x,x.y,x.z,d),!1,0.6,0.9,0.4)},
$S:148}
C.bRk.prototype={
$2(d,e){var x,w=this,v=null,u=A.aE(A.w(v,v,B.n,v,v,new A.x(B.c1,v,v,A.i(2),v,v,B.u),v,4,v,B.e3,v,v,v,40),v,v),t=A.i(6),s=w.d,r=A.a5(s,1.2),q=w.b,p=y.u
t=A.a([u,A.u(A.a([A.w(v,A.c(q.asg(w.e),v,v,v,v,A.A(v,v,s,v,v,v,v,v,v,v,v,11,v,v,B.w,v,v,!0,v,0.8,v,v,v,v,v,v),v,v,v),B.n,v,v,new A.x(w.c,v,r,t,v,v,B.u),v,v,v,v,B.d3,v,v,v),B.al,A.J(A.c(w.a.a,v,v,v,v,A.A(v,v,B.av,v,v,v,v,v,v,v,v,12,v,v,v,v,v,!0,v,v,v,v,v,v,v,v),v,v,v),1,v)],p),B.k,B.f,B.i,0,v,v),B.F,A.c(w.f,v,v,v,v,B.cO,v,v,v),B.P,B.eU,B.N,q.a6K("Actor / Performed By",w.r,B.J1)],p)
u=w.w
if(u.length!==0)t.push(q.a6K("Entity Category",u.toUpperCase(),B.VH))
u=w.x
if(u.length!==0)t.push(q.a6K("Entity Record ID",u,B.pT))
u=w.y
if(u!=null&&u.gc8(u)){s=w.z
r=s?D.awI:B.fO
q=A.i(10)
x=A.a5(s?B.eq:B.bD,1)
u=u.gdA()
B.h.B(t,A.a([B.F,D.cFt,B.N,A.w(v,A.z(u.dK(u,new C.bRi(),y.x).cF(0),B.x,v,B.f,B.i,0,B.o),B.n,v,v,new A.x(r,v,x,q,v,v,B.u),v,v,v,v,B.aS,v,v,v)],p))}t.push(B.bl)
t.push(A.k_(D.aMc,B.m7,new C.bRj(w.Q),v))
return A.fo(t,e,D.aC9,v,v,!1)},
$S:1846}
C.bRi.prototype={
$1(d){var x=null
return new A.U(B.HL,A.u(A.a([A.bk(A.c(d.a,x,x,x,x,A.A(x,x,B.av,x,x,x,x,x,x,x,x,12,x,x,B.a1,x,x,!0,x,x,x,x,x,x,x,x),x,x,x),x,120),A.J(A.c(A.r(d.b),x,x,x,x,B.aiJ,x,x,x),1,x)],y.u),B.x,B.f,B.i,0,x,x),x)},
$S:1847}
C.bRj.prototype={
$0(){A.a8(this.a,!1).S(null)
return null},
$S:0}
C.bRu.prototype={
$0(){var x=this.a,w=A.af(x).c
w===$&&A.b()
return w.cs()?A.af(x).S(null):A.af(x).b4("/admin/home",null)},
$S:0}
C.bRv.prototype={
$0(){var x=this.a,w=A.af(x).c
w===$&&A.b()
return w.cs()?A.af(x).S(null):A.af(x).b4("/admin/home",null)},
$S:0}
C.bRw.prototype={
$0(){var x=this.a
x.v(new C.bRt(x))},
$S:0}
C.bRt.prototype={
$0(){var x=this.a
x.x=""
x.y.fV(B.fq)},
$S:0}
C.bRx.prototype={
$1(d){var x=this.a
return x.v(new C.bRs(x,d))},
$S:8}
C.bRs.prototype={
$0(){return this.a.x=B.d.q(this.b).toLowerCase()},
$S:0}
C.bRy.prototype={
$2(d,e){var x,w,v,u,t
if(e.a===B.fa)return B.ba
x=e.b
w=x==null?null:x.ga2()
if(w==null)w=A.a([],y.C)
if(w.length===0)return D.aDi
x=A.ab(w).i("X<1,ae<e,@>>")
v=A.Z(new A.X(w,new C.bRn(),x),x.i("aJ.E"))
B.h.cK(v,new C.bRo())
x=this.a
u=A.ab(v).i("au<1>")
t=A.Z(new A.au(v,new C.bRp(x),u),u.i("P.E"))
u=t.length
if(u===0)return D.asf
return A.lo(null,new C.bRq(x,t,this.b),u,B.hT,null,new C.bRr(),!1)},
$S:90}
C.bRn.prototype={
$1(d){return d.I()},
$S:115}
C.bRo.prototype={
$2(d,e){var x,w,v="timestamp",u=d.h(0,v),t=e.h(0,v),s=A.az(1970,1,1,0,0,0,0),r=A.az(1970,1,1,0,0,0,0)
if(u instanceof A.dX)s=A.eG(u.gbd())
if(t instanceof A.dX)r=A.eG(t.gbd())
if(typeof u=="string"){x=A.dB(u)
s=x==null?s:x}if(typeof t=="string"){w=A.dB(t)
r=w==null?r:w}return r.b8(0,s)},
$S:190}
C.bRp.prototype={
$1(d){var x,w,v,u,t,s=d.h(0,"action"),r=J.L(s==null?"":s).toLowerCase()
s=d.h(0,"entityType")
x=J.L(s==null?"":s).toLowerCase()
s=this.a
w=s.a90(d)
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
$S:23}
C.bRr.prototype={
$2(d,e){return B.bY},
$S:84}
C.bRq.prototype={
$2(d,e){var x,w,v,u,t,s,r,q,p,o,n,m=null,l=this.b[e],k=l.h(0,"action"),j=J.L(k==null?"":k)
k=this.a
x=k.a90(l)
w=l.h(0,"userEmail")
if(w==null)w=l.h(0,"userName")
v=J.L(w==null?"Admin":w)
u=l.h(0,"timestamp")
if(u!=null){t=u instanceof A.dX?A.eG(u.gbd()):m
if(typeof u=="string")t=A.dB(u)
s=t!=null?A.aL("dd MMM yyyy, hh:mm a",m).a9(t):""}else s=""
w=this.c
r=k.a93(j,w)
q=k.ash(j,w)
w=A.i(6)
p=A.a5(r,1.2)
w=A.w(m,A.c(k.asg(j),m,m,m,m,A.A(m,m,r,m,m,m,m,m,m,m,m,10,m,m,B.w,m,m,!0,m,0.6,m,m,m,m,m,m),m,m,m),B.n,m,m,new A.x(q,m,p,w,m,m,B.u),m,m,m,m,B.cW,m,m,m)
p=A.c(x,m,m,m,m,B.hE,m,m,m)
o=y.u
n=A.a([A.Y(B.J1,B.av,m,m,13),B.an,A.J(A.c(v,1,B.Z,m,m,A.A(m,m,B.av,m,m,m,m,m,m,m,m,11.5,m,m,m,m,m,!0,m,m,m,m,m,m,m,m),m,m,m),1,m)],o)
if(s.length!==0)B.h.B(n,A.a([B.D,A.c(s,m,m,m,m,A.A(m,m,B.dX,m,m,m,m,m,m,m,m,11,m,m,m,m,m,!0,m,m,m,m,m,m,m,m),m,m,m)],o))
return A.bn(!1,m,!0,new A.U(B.hW,A.u(A.a([w,B.a3,A.J(A.z(A.a([p,B.aJ,A.u(n,B.k,B.f,B.i,0,m,m)],o),B.x,m,B.f,B.i,0,B.o),1,m),B.am,B.JV],o),B.x,B.f,B.i,0,m,m),m),m,!0,m,m,m,m,m,m,m,m,m,m,m,new C.bRm(k,d,l),m,m,m,m,m,m,m)},
$S:103}
C.bRm.prototype={
$0(){return this.a.buo(this.b,this.c)},
$S:0}
C.bRh.prototype={
$1(d){var x=this.a
return x.v(new C.bRg(x,this.b))},
$S:2}
C.bRg.prototype={
$0(){return this.a.w=this.b},
$S:0};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(C.DX,A.oB)
x(C.aCB,A.nP)
w(A.ma,[C.bRl,C.bRi,C.bRx,C.bRn,C.bRp,C.bRh])
w(A.oA,[C.bRk,C.bRy,C.bRo,C.bRr,C.bRq])
w(A.oz,[C.bRj,C.bRu,C.bRv,C.bRw,C.bRt,C.bRs,C.bRm,C.bRg])})()
A.vD(b.typeUniverse,JSON.parse('{"DX":{"ak":[],"v":[]},"aCB":{"ap":["DX"]}}'))
var y={C:A.ay("a2<fD<ae<e,@>>>"),u:A.ay("a2<v>"),y:A.ay("ae<e,@>"),x:A.ay("U"),t:A.ay("dl<ae<e,@>>"),w:A.ay("e"),b:A.ay("@"),v:A.ay("e?")};(function constants(){D.cFj=new A.f("No matching audit records for this filter.",null,B.ia,null,null,null,null,null,null,null,null)
D.c1P=new A.U(B.eW,D.cFj,null)
D.asf=new A.d4(B.a4,null,null,D.c1P,null)
D.aw4=new A.S(1,0.11764705882352941,0.11764705882352941,0.11764705882352941,B.A)
D.awI=new A.S(1,0.1568627450980392,0.1568627450980392,0.1568627450980392,B.A)
D.aBn=new A.ai(16,0,16,10)
D.aC9=new A.ai(20,16,20,32)
D.aGT=new A.a1(61509,"MaterialIcons",null,!1)
D.aDi=new A.yg(D.aGT,"No audit records found","All your administrative actions, payments, and seat updates will appear here in real-time.",null,null,null)
D.aKJ=new A.y(B.t2,20,null,null,null)
D.aMc=new A.y(B.mK,18,null,null,null)
D.ceM=new A.am(1/0,60)
D.cze=new A.f("Audit Log",null,null,null,null,null,null,null,null,null,null)
D.cFt=new A.f("Operation Parameters & Details",null,B.by,null,null,null,null,null,null,null,null)
D.cK0=new A.f("Audit Trail & Activity Log",null,null,null,null,null,null,null,null,null,null)})()};
(a=>{a["U2bi3Dzv7c39dmOrXX+n/ksLg0w="]=a.current})($__dart_deferred_initializers__);