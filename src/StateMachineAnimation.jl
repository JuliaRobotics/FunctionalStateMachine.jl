


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


function renderStateMachineFrame(vg,
                                 frame::Int;
                                 title::String="",
                                 viewerapp::String="eog",
                                 fext::String="png",
                                 engine::String="dot",
                                 show::Bool=true,
                                 folder::String="fsm_animation",
                                 timest::String="",
                                 rmfirst::Bool=false  )
  #
  folderpath = "/tmp/$folder/"
  if rmfirst
    @warn "removing contents of $(folderpath)"
    Base.rm(folderpath, recursive=true, force=true)
  end
  mkpath(folderpath)
  dotfile = "$folderpath/csm_$frame.dot"
  filepath= "$folderpath/csm_$frame.$(fext)"

  # dot file handle
  fid = open(dotfile,"w")
  write(fid,Graphs.to_dot(vg))
  close(fid)

  # build the dot file somewhat manually
  fid = open("$folderpath/dotscript.sh","w")
  str = "head -n `wc -l $dotfile | awk '{print \$1-1}'` $dotfile > $folderpath/tmpdot.dot"
  println(fid, str)
  println(fid, "echo \"graph [label=\\\"$title, #$step, $(timest)\\\", labelloc=t];\" >> $folderpath/tmpdot.dot")
  println(fid, "echo \"}\" >> $folderpath/tmpdot.dot")
  close(fid)
  run(`chmod u+x $folderpath/dotscript.sh`)
  run(`sh $folderpath/dotscript.sh`)
  Base.rm(dotfile)
  Base.rm("$folderpath/dotscript.sh")
  run(`mv $folderpath/tmpdot.dot $dotfile`)

  # compile output and maybe show to user
  run(`$(engine) $(dotfile) -T$(fext) -o $(filepath)`)
  show ? (@async run(`$viewerapp $filepath`)) : nothing
  return filepath
end

function setVisGraphOnState!(vg, vertid; xlabel::String="", appendxlabel::String="")
  #
  vg.vertices[vertid].attributes["fillcolor"] = "red"
  vg.vertices[vertid].attributes["style"] = "filled"
  if length(xlabel) > 0
    vg.vertices[vertid].attributes["xlabel"] = xlabel
  end
  if haskey(vg.vertices[vertid].attributes, "xlabel")
    vg.vertices[vertid].attributes["xlabel"] = vg.vertices[vertid].attributes["xlabel"]*appendxlabel
  elseif length(appendxlabel) > 0
    vg.vertices[vertid].attributes["xlabel"] = appendxlabel
  end
end

function clearVisGraphAttributes!(vg)
  for (vid,vert) in vg.vertices
    haskey(vert.attributes, "fillcolor") ? delete!(vert.attributes, "fillcolor") : nothing
    haskey(vert.attributes, "style") ? delete!(vert.attributes, "style") : nothing
    haskey(vert.attributes, "xlabel") ? delete!(vert.attributes, "xlabel") : nothing
  end
  nothing
end

function drawStateTransitionStep(hist,
                                 step::Int,
                                 vg,
                                 lookup::Dict{Symbol,Int};
                                 title::String="",
                                 viewerapp::String="eog",
                                 fext::String="png",
                                 engine::String="dot",
                                 show::Bool=true,
                                 folder::String="",
                                 frame::Int=step  )
  #

  lbl = getStateLabel(hist[step][3])
  vertid = lookup[lbl]
  vert = vg.vertices[vertid]

  fillcolorbefore = haskey(vert.attributes, "fillcolor") ? deepcopy(vg.vertices[vertid].attributes["fillcolor"]) : nothing
  stylebefore = haskey(vert.attributes, "style") ? deepcopy(vg.vertices[vertid].attributes["style"]) : nothing
  xlabelbefore = haskey(vg.vertices[vertid].attributes,"xlabel") ? deepcopy(vg.vertices[vertid].attributes["xlabel"]) : nothing
  # delete!(vert.attributes, "fillcolor")
  # delete!(vert.attributes, "style")

  # identify and set the node
  xlabel = length(title) > 0 ? (xlabelbefore != nothing ? xlabelbefore*"," : "")*title : ""
  setVisGraphOnState!(vg, vertid, xlabel=xlabel)

  # render state machine frame
  filepath = renderStateMachineFrame(vg,
                                     frame,
                                     title=title,
                                     viewerapp=viewerapp,
                                     fext=fext,
                                     engine=engine,
                                     show=show,
                                     folder=folder,
                                     timest=string(split(string(hist[step][1]),'T')[end]),
                                     rmfirst=false)
  #

  # clean up the vg structure
  fillcolorbefore == nothing ? delete!(vert.attributes, "fillcolor") : (vert.attributes["fillcolor"]=fillcolorbefore)
  stylebefore == nothing ? delete!(vert.attributes, "style") : (vert.attributes["style"]=stylebefore)
  xlabelbefore == nothing ? delete!(vert.attributes, "xlabel") : (vert.attributes["xlabel"]=xlabelbefore)

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
                                          stopT=hist[end][1],
                                          rmfirst::Bool=true  ) where T
  #
  stateVisits, allStates = histStateMachineTransitions(hist)

  vg, lookup = histGraphStateMachineTransitions(stateVisits, allStates)

  totT = stopT - startT
  totT = Millisecond(round(Int, 1.05*totT.value))
  # totT *= 1.05

  step = 1
  len = length(hist)
  @showprogress "exporting state machine images, $title " for i in 1:frames
    aniT = Millisecond(round(Int, i/frames*totT.value)) + startT
    # aniT = i/frames*totT + startT
    if hist[step][1] < aniT && step < len
      step += 1
    end
    drawStateTransitionStep(hist, step, vg, lookup, title=title, folder=folder, show=show, frame=i)
  end

  nothing
end

function animateStateMachineHistoryByTimeCompound(hists::Dict{Symbol, Vector{Tuple{DateTime, Int, <: Function, T}}},
                                                  startT,
                                                  stopT;
                                                  frames::Int=100,
                                                  folder="animatestate",
                                                  title::String="",
                                                  show::Bool=false,
                                                  clearstale::Bool=true,
                                                  rmfirst::Bool=true  ) where T
  #
  # Dict{Symbol, Vector{Symbol}}
  stateVisits = Dict{Symbol, Vector{Symbol}}()
  allStates = Vector{Symbol}()
  for (csym,hist) in hists
    stateVisits, allStates = histStateMachineTransitions(hist,allStates=allStates, stateVisits=stateVisits  )
  end

  #
  vg, lookup = histGraphStateMachineTransitions(stateVisits, allStates)

  # total draw time and step initialization
  totT = stopT - startT
  totT = Millisecond(round(Int, 1.05*totT.value))
  histsteps = ones(Int, length(hists))

  # clear any stale state
  clearstale ? clearVisGraphAttributes!(vg) : nothing

  # loop across time
  @showprogress "exporting state machine images, $title " for i in 1:frames
    # calc frame time
    aniT = Millisecond(round(Int, i/frames*totT.value)) + startT

    # loop over all state machines
    histidx = 0
    for (csym, hist) in hists
      histidx += 1
      step = histsteps[histidx]
      len = length(hist)
      if hist[step][1] < aniT && step < len
        histsteps[histidx] += 1
      end
      # redefine after +1
      step = histsteps[histidx]

      # modify vg for each history
      lbl = getStateLabel(hist[step][3])
      vertid = lookup[lbl]
      setVisGraphOnState!(vg, vertid, appendxlabel=string(csym)*",")
    end

    # finally render one frame
    renderStateMachineFrame(vg,
                            i,
                            title=title,
                            show=false,
                            folder=folder,
                            timest=string(split(string(aniT),' ')[1]),
                            rmfirst=false  )
    #
    clearVisGraphAttributes!(vg)
  end

end
