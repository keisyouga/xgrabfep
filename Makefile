# create linux binary
# prerequisite : sdx tclkit libtkxwin.so

SDX != command -v sdx
TCLKIT != command -v tclkit
TCLKIT_RUNTIME = tclkit-runtime
VFSDIR = xgrabfep.vfs

xgrabfep-linux-x86_64: main.tcl libtkxwin.so ${TCLKIT_RUNTIME}
	mkdir -p ${VFSDIR}
	cp main.tcl ${VFSDIR}/
	mkdir -p ${VFSDIR}/lib/tkxwin
	cp libtkxwin.so ${VFSDIR}/lib/tkxwin/
	echo 'package ifneeded tkxwin 1.0.0 [list load [file join $$dir libtkxwin.so]]' > ${VFSDIR}/lib/tkxwin/pkgIndex.tcl
	${TCLKIT} ${SDX} wrap xgrabfep-linux-x86_64 -vfs ${VFSDIR} -runtime ${TCLKIT_RUNTIME}

${TCLKIT_RUNTIME}:
	cp ${TCLKIT} ${TCLKIT_RUNTIME}

clean:
	${RM} ${VFSDIR}/lib/tkxwin/libtkxwin.so
	${RM} ${VFSDIR}/lib/tkxwin/pkgIndex.tcl
	${RM} ${VFSDIR}/main.tcl
	rmdir -p ${VFSDIR}/lib/tkxwin || true
	${RM} ${TCLKIT_RUNTIME}
