(* ::Package:: *)

(* ::Text:: *)
(*Amino Acid Alphabet*)


AlphaAAs={"-","A","C","D","E","F","G","H","I","K","L","M","N","P","Q","R","S","T","V","W","Y"};


(* ::Text:: *)
(*Imports closest pairwise distances from PDB file between SH2 domain and peptide.*)


ImportClosestDistances[file_,lengths_:{77,17}]:=Module[
	{raw=Import[file,"Table"],rawDomain,rawPeptide,coordsDomain,coordsPeptide,idxDomain,idxPeptide},
	{coordsDomain,coordsPeptide}=ConstantArray[Null,#]&/@lengths;
	{rawDomain,rawPeptide}=GatherBy[Cases[raw,{"ATOM",_,_,_,#,__}],#[[6]]&]&/@{"A","B"};
	idxDomain=rawDomain[[All,1,6]];
	idxPeptide=rawPeptide[[All,1,6]]-lengths[[1]];
	coordsDomain[[idxDomain]]=rawDomain[[All,All,7;;9]];
	coordsPeptide[[idxPeptide]]=rawPeptide[[All,All,7;;9]];
	Outer[If[#1===Null\[Or]#2===Null,Null,Min[Outer[EuclideanDistance,##,1]]]&,coordsDomain,coordsPeptide,1]]


(* ::Text:: *)
(*Imports a \[Beta] vector for the SH2 model and returns a matrix, formatted as {{\[Lambda],domain_position,domain_AA},{\[Lambda],peptide_position,peptide_AA},{\[Lambda],domain_position,peptide_position,domain_AA,peptide_AA}} where the first two lists represent first-order terms and the last one represents all the second order terms.*)


ImportBetaMatrix[file_String,seqRepDomain_,seqRepPeptide_,opts:OptionsPattern[SequenceToPositionBasedFeatures]]:=Module[
	{raw=Import[file,"MTX"],
	 idxY=StringPosition[seqRepPeptide,OptionValue[PYResidue]][[1,1]],
	 struct=SequenceToPositionBasedFeatures[seqRepDomain,seqRepPeptide,opts,Structured->True],
	 posFirstOrderDomain=OptionValue[FirstOrderDomain]/.{None->{},All->Range[StringLength[seqRepDomain]]},
	 posFirstOrderPeptide=OptionValue[FirstOrderPeptide]/.{None->{},All->Range[StringLength[seqRepPeptide]]},
	 posSecondOrder=OptionValue[SecondOrder],
	 alphaIncludedDomain=OptionValue[IncludedResiduesDomain],
	 alphaIncludedPeptide=OptionValue[IncludedResiduesPeptide],
	 lens,takes,structured,paddingY,vec1stOrderDomain,vec1stOrderPeptide,mat2ndOrder,idxPosY},
	paddingY={Position[alphaIncludedPeptide,ToUpperCase[OptionValue[PYResidue]]][[1,1]]-1,Length[alphaIncludedPeptide]-Position[alphaIncludedPeptide,ToUpperCase[OptionValue[PYResidue]]][[1,1]]};
	idxPosY=Flatten[Position[posFirstOrderPeptide,idxY]];
	lens=Map[Length,struct,{2}];
	takes=MapThread[
		If[#1==={},{},Transpose[Transpose[Partition[Prepend[Accumulate[#1],0],2,1]]+{1,0}]+#2]&,
		{lens,Accumulate[Prepend[Total/@Most[lens],0]]}];
	vec1stOrderDomain=Transpose[ReplacePart[
		ConstantArray[SparseArray[{},{Length[alphaIncludedDomain],Dimensions[raw][[2]]}],StringLength[seqRepDomain]],
		Thread[posFirstOrderDomain->(Take[raw,#]&/@takes[[1]])]],{2,3,1}];
	vec1stOrderPeptide=Transpose[ReplacePart[
		ConstantArray[SparseArray[{},{Length[alphaIncludedPeptide],Dimensions[raw][[2]]}],StringLength[seqRepPeptide]],
		Thread[Delete[posFirstOrderPeptide,idxPosY]->(Take[raw,#]&/@Delete[takes[[2]],idxPosY])]],{2,3,1}];
	mat2ndOrder=ReplacePart[
		ConstantArray[
			SparseArray[{},{Length[alphaIncludedDomain],Length[alphaIncludedPeptide],Dimensions[raw][[2]]}],
			{StringLength[seqRepDomain],StringLength[seqRepPeptide]}],
		Thread[posSecondOrder->(Partition[Take[raw,#],Length[Range@@#]/Length[alphaIncludedDomain]]&/@takes[[3]])]];
	mat2ndOrder=Transpose[MapAt[ArrayPad[#,{{0,0},paddingY,{0,0}}]&,mat2ndOrder,Cases[posSecondOrder,{_,idxY}]],{2,3,4,5,1}];
	Map[SparseArray,Transpose[{vec1stOrderDomain,vec1stOrderPeptide,mat2ndOrder}],{3}]]


(* ::Text:: *)
(*Function upper triangularizes a matrix, flattens it, and removes the lower triangular elements.*)


FlattenUpperTriangularize[mat_]:=Module[
	{A=Unique[],B=Unique[]},
	DeleteCases[Flatten[UpperTriangularize[mat/.{0.->A,0->B}]],0|0.]/.{A->0.,B->0}]


(* ::Text:: *)
(*Loads symbols into Mathematica contexts*)


Attributes[LoadSymbol]={HoldRest};
Options[LoadSymbol]={IgnoredContexts->{"Global`"}};
LoadSymbol[fldr_String,symbol_Symbol,context_:Context[],OptionsPattern[]]:=With[
	{path=If[MemberQ[OptionValue[IgnoredContexts],context],fldr,FileNameJoin[Prepend[StringSplit[context,"`"],fldr]]],
	 symbolname=SymbolName[Unevaluated[symbol]]},
	If[Length[OwnValues[symbol]]===0,Remove[symbol]];(*Needed because MMA parser otherwise creates symbol in local context.*)
	If[Length[ToExpression["OwnValues["~~context~~symbolname~~"]"]]===0,
	Switch[FileType[FileNameJoin[{path,symbolname}]],
		File,
		Set[Evaluate[Symbol[context~~symbolname]],Get[FileNameJoin[{path,symbolname}]]],
		Directory,
		Set[
			Evaluate[Symbol[context~~symbolname]],
			Hold[Get[#]]&/@Table[FileNameJoin[{path,symbolname,ToString[i]}],{i,Length[FileNames[FileNameJoin[{path,symbolname,"*"}]]]}]]];
	"Loaded "~~symbolname~~" into "~~context~~" from "~~path,
	symbolname~~" is Already Loaded"]]
LoadSymbol[fldr_String,symbols:{__Symbol},context_:Context[],opts:OptionsPattern[]]:=StringJoin[Riffle[
	List@@(Function[symbol,LoadSymbol[fldr,symbol,context,opts],HoldFirst]/@ReplacePart[Unevaluated[symbols],0->Hold]),
	"\n"]]
