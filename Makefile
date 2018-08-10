# $OpenBSD: Makefile,v 1.73 2018/01/31 21:54:49 rsadowski Exp $

COMMENT=	free peer-reviewed portable C++ source libraries

VERSION=	1.67.0
DISTNAME=	boost_${VERSION:S/./_/g}
PKGNAME=	boost-${VERSION}
CATEGORIES=	devel
MASTER_SITES=	${MASTER_SITE_SOURCEFORGE:=boost/}
EXTRACT_SUFX=	.tar.bz2
FIX_EXTRACT_PERMISSIONS =	Yes

SO_VERSION=	9.0
BOOST_LIBS=	boost_atomic-mt \
		boost_chrono-mt boost_chrono \
		boost_container-mt boost_container \
		boost_contract-mt boost_contract \
		boost_date_time-mt boost_date_time \
		boost_filesystem-mt boost_filesystem \
		boost_graph-mt boost_graph \
		boost_iostreams-mt boost_iostreams \
		boost_locale-mt \
		boost_log-mt boost_log \
		boost_log_setup-mt boost_log_setup \
		boost_math_c99-mt boost_math_c99 \
		boost_math_c99f-mt boost_math_c99f \
		boost_math_c99l-mt boost_math_c99l \
		boost_math_tr1-mt boost_math_tr1 \
		boost_math_tr1f-mt boost_math_tr1f \
		boost_math_tr1l-mt boost_math_tr1l \
		boost_prg_exec_monitor-mt boost_prg_exec_monitor \
		boost_program_options-mt boost_program_options \
		boost_python27-mt boost_python27 \
		boost_python36-mt boost_python36 \
		boost_numpy27-mt boost_numpy27 \
		boost_random-mt boost_random \
		boost_regex-mt boost_regex \
		boost_serialization-mt boost_serialization \
		boost_signals-mt boost_signals \
		boost_system-mt boost_system \
		boost_thread-mt \
		boost_timer-mt boost_timer \
		boost_unit_test_framework-mt boost_unit_test_framework \
		boost_wserialization-mt boost_wserialization \
		boost_wave-mt \
		boost_type_erasure-mt boost_type_erasure \

.for _lib in ${BOOST_LIBS}
SHARED_LIBS+=	${_lib} ${SO_VERSION}
.endfor

HOMEPAGE=	http://www.boost.org/

MAINTAINER=	Brad Smith <brad@comstyle.com> \
		Rafael Sadowski <rsadowski@openbsd.org>

# Boost
PERMIT_PACKAGE_CDROM=	Yes

WANTLIB += ${COMPILER_LIBCXX} bz2 c iconv m z

COMPILER= base-clang ports-gcc

MODULES=	lang/python
MODPY_RUNDEP=	No

BUILD_DEPENDS+=	lang/python/${MODPY_DEFAULT_VERSION_2} \
		lang/python/${MODPY_DEFAULT_VERSION_3} \
		math/py-numpy

LIB_DEPENDS=	archivers/bzip2 \
		converters/libiconv

.include <bsd.port.arch.mk>

TOOLSET = clang

.if ${PROPERTIES:Mclang}
TOOLSET=	clang
.else
TOOLSET=	gcc
.endif

MAKE_ENV=	GCC="${CC}" GXX="${CXX}"

BJAM_CONFIG=	-sICONV_PATH=${LOCALBASE} \
		-sBZIP2_INCLUDE=${LOCALBASE}/include \
		-sBZIP2_LIBPATH=${LOCALBASE}/lib \
		-q \
		-j${MAKE_JOBS} \
		--layout=tagged \
		pch=off \
		cflags='${CFLAGS} -pthread' \
		cxxflags='${CXXFLAGS} -pthread' \
		variant=release \
		link=static,shared \
		threading=single,multi \

BOOTSTRAP=	--with-bjam=${WRKSRC}/bjam \
		--with-toolset=${TOOLSET} \
		--with-python-root=${LOCALBASE} \
		--without-icu

# 'context' and 'coroutine' use MD bits and miss support for Alpha,
# PA-RISC, SPARC and SuperH. The author does not care
# about adding support for Alpha and PA-RISC.
BOOTSTRAP+=	--without-libraries=context,coroutine,fiber,stacktrace

PY2_BOOTSTRAP=	--with-python=${LOCALBASE}/bin/python${MODPY_DEFAULT_VERSION_2} \
		--with-python-version=${MODPY_DEFAULT_VERSION_2} \

PY3_BOOTSTRAP=	--with-python=${LOCALBASE}/bin/python${MODPY_DEFAULT_VERSION_3} \
		--with-python-version=${MODPY_DEFAULT_VERSION_3} \

# python.port.mk makes assumptions about an empty CONFIGURE_STYLE
CONFIGURE_STYLE= none

CONFIGURE_ENV=	BJAM_CONFIG="${BJAM_CONFIG}" \
		CXX="${CXX}" CXXFLAGS="${CXXFLAGS}"

DPB_PROPERTIES= parallel

NO_TEST=	Yes

SUBST_VARS+=	SO_VERSION

do-configure:
	echo "using ${TOOLSET} : : ${CXX} ;" >>${WRKSRC}/tools/build/user-config.jam
	@${SUBST_CMD} ${WRKSRC}/Jamroot
	@cd ${WRKSRC}/libs/config && \
		${SETENV} ${CONFIGURE_ENV} /bin/sh ./configure
	@cd ${WRKSRC}/tools/build/src/engine && \
		${SETENV} CC="${CC}" CFLAGS="${CFLAGS}" /bin/sh ./build.sh cc && \
		cp bin.openbsd*/b2 bin.openbsd*/bjam ${WRKSRC}
	@cd ${WRKSRC} && chmod -R a+x ./ && \
	    /bin/sh ./bootstrap.sh ${BOOTSTRAP}

# b2 doesn't seem to respect python parameter, we need to run twice with
# separate python environments
do-build:
	cd ${WRKSRC} && chmod -R a+x ./ && \
	/bin/sh ./bootstrap.sh ${BOOTSTRAP} ${PY2_BOOTSTRAP} && \
	./b2 ${BJAM_CONFIG} python=${MODPY_DEFAULT_VERSION_2} && \
	/bin/sh ./bootstrap.sh ${BOOTSTRAP} ${PY3_BOOTSTRAP} && \
	./b2 ${BJAM_CONFIG} python=${MODPY_DEFAULT_VERSION_3}\

do-install:
	${INSTALL_PROGRAM} ${WRKSRC}/tools/build/src/engine/bin.*/{b2,bjam} \
		${PREFIX}/bin
	${INSTALL_DATA} ${WRKSRC}/stage/lib/lib!(*.so) ${PREFIX}/lib
	@cd ${WRKSRC} && \
		find boost -type d -exec ${INSTALL_DATA_DIR} ${PREFIX}/include/{} \;
	@cd ${WRKSRC} && \
		find boost ! -name \*.orig -type f -exec ${INSTALL_DATA} {} ${PREFIX}/include/{} \;

.include <bsd.port.mk>
