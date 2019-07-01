


"""
    $SIGNATURES

Create a `Graphs.incdict` object and populate with nodes (states) and edges (transitions)
according to the contents of parameters passed in.

Notes:
- Current implementation repeats duplicate transitions as new edges.
"""
function histGraphStateMachineTransitions(stateVisits, allStates::Vector{Symbol})

  g = Graphs.incdict(Graphs.ExVertex,is_directed=true)
  lookup = Dict{Symbol, Int}()

  # add all required states as nodes to the visualization graph
  fid = 0
  for state in allStates
    fid += 1
    lbl = string(state)
    exvert = Graphs.ExVertex(fid, lbl)
    exvert.attributes["label"] = lbl
    Graphs.add_vertex!(g, exvert)
    lookup[state] = fid
  end

  # add all edges to graph
  count = 0
  for (from, tos) in stateVisits
    for to in tos
      count += 1
      exvf = g.vertices[lookup[from]]
      exvt = g.vertices[lookup[to]]
      # add the edge fom one to the next state
      edge = Graphs.make_edge(g, exvf, exvt)
      Graphs.add_edge!(g, edge)
    end
  end

  return g, lookup
end



function drawStateTransitionStep(hist,
                                 step::Int,
                                 vg,
                                 lookup::Dict{Symbol,Int};
                                 title::String="",
                                 viewerapp="eog",
                                 fext="png",
                                 engine = "dot",
                                 show::Bool=true,
                                 folder::String="",
                                 frame::Int=step  )
  #

  mkpath("/tmp/$folder/")
  dotfile = "/tmp/$folder/csm_$frame.dot"
  filepath="/tmp/$folder/csm_$frame.$(fext)"

  vert = fg.vertices[vertid]
  fillcolorbefore = haskey(vert.attributes, "fillcolor") ? deepcopy(vg.vertices[vertid].attributes["fillcolor"]) : nothing
  stylebefore = haskey(vert.attributes, "style") ? deepcopy(vg.vertices[vertid].attributes["style"]) : nothing
  xlabelbefore = haskey(vg.vertices[vertid].attributes,"xlabel") ? deepcopy(vg.vertices[vertid].attributes["xlabel"]) : nothing
  # delete!(vert.attributes, "fillcolor")
  # delete!(vert.attributes, "style")

  # identify and set the node
  lbl = getStateLabel(hist[step][3])
  vertid = lookup[lbl]
  vg.vertices[vertid].attributes["fillcolor"] = "red"
  vg.vertices[vertid].attributes["style"] = "filled"
  if length(title) > 0
    vg.vertices[vertid].attributes["xlabel"] = xlabelbefore*","*title
  end

  # dot file handle
  fid = open(dotfile,"w")
  write(fid,Graphs.to_dot(vg))
  close(fid)

  # build the dot file somewhat manually
  timest = split(string(hist[step][1]),'T')[end]
  fid = open("/tmp/$folder/dotscript.sh","w")
  str = "head -n `wc -l $dotfile | awk '{print \$1-1}'` $dotfile > /tmp/$folder/tmpdot.dot"
  println(fid, str)
  println(fid, "echo \"graph [label=\\\"$title, #$step, $(timest)\\\", labelloc=t];\" >> /tmp/$folder/tmpdot.dot")
  println(fid, "echo \"}\" >> /tmp/$folder/tmpdot.dot")
  close(fid)
  run(`chmod u+x /tmp/$folder/dotscript.sh`)
  run(`sh /tmp/$folder/dotscript.sh`)
  Base.rm(dotfile)
  Base.rm("/tmp/$folder/dotscript.sh")
  run(`mv /tmp/$folder/tmpdot.dot $dotfile`)

  # clean up the vg structure
  fillcolorbefore == nothing ? delete!(vert.attributes, "fillcolor") : (vert.attributes["fillcolor"]=fillcolorbefore)
  stylebefore == nothing ? delete!(vert.attributes, "style") : (vert.attributes["style"]=stylebefore)
  xlabelbefore == nothing ? delete!(vert.attributes, "xlabel") : (vert.attributes["xlabel"]=xlabelbefore)

  # compile output and maybe show to user
  run(`$(engine) $(dotfile) -T$(fext) -o $(filepath)`)
  show ? (@async @async run(`$viewerapp $filepath`)) : nothing

  return filepath
end





function drawStateMachineHistory(hist; show::Bool=false, folder::String="")

  stateVisits, allStates = histStateMachineTransitions(hist)

  vg, lookup = histGraphStateMachineTransitions(stateVisits, allStates)

  for i in 1:length(hist)
    drawStateTransitionStep(hist, i, vg, lookup, folder=folder, show=show)
  end

  return nothing
end



"""
    $SIGNATURES

Draw simultaneously separate time synchronized frames from each of the desired
state machines.  These images can be produced into synchronous side-by-side videos
which allows for easier debugging and comparison of concurrently running state
machines.
"""
function animateStateMachineHistoryByTime(hist::Vector{Tuple{DateTime, Int, <: Function, T}};
                                          frames::Int=100,
                                          folder="animatestate",
                                          title::String="",
                                          show::Bool=false,
                                          startT=hist[1][1],
                                          stopT=hist[end][1]  ) where T
  #
  stateVisits, allStates = histStateMachineTransitions(hist)

  vg, lookup = histGraphStateMachineTransitions(stateVisits, allStates)

  totT = stopT - startT

  step = 1
  len = length(hist)
  @showprogress "exporting state machine images, $title " for i in 1:frames
    aniT = i/frames*totT + startT
    if hist[step][1] < aniT && step < len
      step += 1
    end
    drawStateTransitionStep(hist, step, vg, lookup, title=title, folder=folder, show=show, frame=i)
  end

  nothing
end

function animateStateMachineHistoryByTimeCompound(hists::Vector{Vector{Tuple{DateTime, Int, <: Function, T}}};
                                                  frames::Int=100,
                                                  folder="animatestate",
                                                  title::String="",
                                                  show::Bool=false,
                                                  startT=hist[1][1],
                                                  stopT=hist[end][1]  ) where T
  #
  # Dict{Symbol, Vector{Symbol}}
  stateVisits = Dict{Symbol, Vector{Symbol}}()
  allStates = Vector{Symbol}()
  for hist in hists
    stateVisits, allStates = histStateMachineTransitions(hist,allStates=allStates, stateVisits=stateVisits  )
  end

  #
  vg, lookup = histGraphStateMachineTransitions(stateVisits, allStates)

  # total draw time and step initialization
  totT = stopT - startT
  step = 1


end
